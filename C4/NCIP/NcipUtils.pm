#!/usr/bin/perl

# Copyright 2014 ByWater Solutions
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

package C4::NCIP::NcipUtils;

use Modern::Perl;
use JSON qw(to_json);

=head1 NAME

C4::NCIP::NcipUtils - NCIP Common subroutines used in most of C4::NCIP modules

=head1 SYNOPSIS

  use C4::NCIP::NcipUtils;

=head1 DESCRIPTION

        Info about NCIP and it's services can be found here: http://www.niso.org/workrooms/ncip/resources/

=cut

=head1 METHODS

=cut

=head2 canBeRenewed

	canBeRenewed($cgiInput)

=cut

sub canBeRenewed {
    my $query  = shift;
    my $userId = $query->param('userId');
    my $itemId = $query->param('itemId');
    my $response;

    my ($okay, $error)
        = C4::Circulation::CanBookBeRenewed($userId, $itemId, '0');

    $response->{allowed} = $okay ? 'y' : 'n';

    printJson($query, $response) unless $okay;

    my $maxDateDueDesired = $query->param('maxDateDueDesired');

    if (defined $maxDateDueDesired) {
        my $dbh = C4::Context->dbh;
        # Find the issues record for this book
        my $sth = $dbh->prepare(
            "SELECT branchcode FROM issues WHERE itemnumber = ?");
        $sth->execute($itemId);
        my $issueBranchCode = $sth->fetchrow_array;
        unless ($issueBranchCode) {
            print $query->header(
                -type   => 'text/plain',
                -status => '404 Not Found'
            );
            print 'Checkout wasn\'t found .. Nothing to renew..';
            exit 0;
        }

        my $biblio = C4::Biblio::GetBiblioFromItemNumber($itemId);
        my $itemtype
            = (C4::Context->preference('item-level_itypes'))
            ? $biblio->{'itype'}
            : $biblio->{'itemtype'};

        my $now = DateTime->now(time_zone => C4::Context->tz());
        my $borrower = C4::Members::GetMember(borrowernumber => $userId);
        unless ($borrower) {
            print $query->header(
                -type   => 'text/plain',
                -status => '404 Not Found'
            );
            print 'User wasn\'t found ..';
            exit 0;
        }

        my $maxDateDue
            = C4::Circulation::CalcDateDue($now, $itemtype, $issueBranchCode,
            $borrower, 'is a renewal');
        $response->{maxDateDue}
            = Koha::DateUtils::format_sqldatetime($maxDateDue);
    }
    printJson($query, $response);
}

=head2 canBeRequested

	canBeRequested($cgiInput)

=cut

sub canBeRequested {
    my ($query) = @_;
    my $userId  = $query->param('userId');
    my $itemId  = $query->param('itemId');

    # get borrower information ....
    my ($borr) = C4::Members::GetMemberDetails($userId);

    print404($query, "User doesn't exist") unless $borr;

    my $response;
    if ($borr->{'BlockExpiredPatronOpacActions'}) {
        if ($borr->{'is_expired'}) {
            $response->{allowed} = 'n';
            $response->{reason}  = 'expired';
            printJson($query, $response);
        }
    }

    if (C4::Members::IsDebarred($userId)) {
        $response->{allowed} = 'n';
        $response->{reason}  = 'debarred';
        printJson($query, $response);
    }

    my $canReserve = C4::Reserves::CanItemBeReserved($userId, $itemId);

    my $response;
    $response->{allowed} = $canReserve eq 'OK' ? 'y' : 'n';

    printJson($query, $response);
}

=head2 clearEmptyKeys

	clearEmptyKeys($hashref)

=cut

sub clearEmptyKeys {
    my ($hashref) = @_;

    return undef unless $hashref;

    foreach my $key (keys $hashref) {
        delete $hashref->{$key} unless $hashref->{$key};
    }
    return $hashref;
}

=head2 clearEmptyKeysWithinArray

	clearEmptyKeysWithinArray($arrayWithHashrefs)

=cut

sub clearEmptyKeysWithinArray {
    my (@arrayOfHashrefs) = @_;

    for (my $i = 0; $i < scalar @arrayOfHashrefs; ++$i) {
        clearEmptyKeys($arrayOfHashrefs[$i]);
    }
    return \@arrayOfHashrefs;
}

=head2 parseCirculationStatus

	parseCirculationStatus($item, $numberOfHoldsOnItem)

	Returns one of these:
		On Loan
		In Transit Between Library Locations
		Not Available
		Available On Shelf

=cut

sub parseCirculationStatus {
    my ($item, $holds) = @_;

    if ($holds != 0 or $item->{datedue} or $item->{onloan}) {
        return 'On Loan';
    }
    if ($item->{transfertwhen}) {
        return 'In Transit Between Library Locations';
    }
    if (   $item->{notforloan_per_itemtype}
        or $item->{itemlost}
        or $item->{withdrawn}
        or $item->{damaged})
    {
        return 'Not Available';
    }

    return 'Available On Shelf';
}

=head2 parseItemUseRestrictions

	parseItemUseRestrictions($item)

	Returns array of restriction NCIP formatted
	For now can return only 'In Library Use Only' within array if $item->{notforloan} is true

=cut

sub parseItemUseRestrictions {
# Possible standardized values can be found here:
# https://code.google.com/p/xcncip2toolkit/source/browse/core/trunk/service/src/main/java/org/extensiblecatalog/ncip/v2/service/Version1ItemUseRestrictionType.java

    my ($item) = @_;

    my @toReturn;
    my $i = 0;
    if ($item->{notforloan}) {
        $toReturn[$i++] = 'In Library Use Only';
    }
    return \@toReturn;
}

=head2 printJson

	printJson($cgiInput, $hashref)

	Prints header as text/plain with charset utf-8 and status 200 & converts $hashref to json format being printed to output.

=cut

sub printJson {
    my ($query, $string) = @_;
    print $query->header(
        -type    => 'text/plain',
        -charset => 'utf-8',
        -status  => '200 OK'
        ),
        to_json($string);
    exit 0;
}

=head2 print400

	print400($cgiInput, $message)

=cut

sub print400 {
    my ($query, $string) = @_;
    print $query->header(-type => 'text/plain', -status => '400 Bad Request'),
        $string;
    exit 0;
}

=head2 print403

        print403($cgiInput, $message)

=cut

sub print403 {
    my ($query, $string) = @_;
    print $query->header(-type => 'text/plain', -status => '403 Forbidden'),
        $string;
    exit 0;
}

=head2 print404

        print404($cgiInput, $message)

=cut

sub print404 {
    my ($query, $string) = @_;
    print $query->header(-type => 'text/plain', -status => '404 Not Found'),
        $string;
    exit 0;
}

=head2 print409

        print409($cgiInput, $message)

=cut

sub print409 {
    my ($query, $string) = @_;
    print $query->header(-type => 'text/plain', -status => '409 Conflict'),
        $string;
    exit 0;
}

1;
