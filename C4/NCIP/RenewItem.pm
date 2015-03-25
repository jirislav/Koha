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

package C4::NCIP::RenewItem;

use Modern::Perl;

use JSON qw(to_json);

sub renewItem {
    my $query  = shift;
    my $itemId = $query->param('itemId');
    my $userId = $query->param('userId');
    my $branch = $query->param('branch') || C4::Context->userenv->{'branch'};
    my $biblio = C4::Biblio::GetBiblioFromItemNumber($itemId);

    unless ($itemId) {
        print $query->header(
            -type   => 'text/plain',
            -status => '400 Bad Request'
        );
        print "itemId is undefined..";
        exit 0;
    }

    unless ($userId) {
        print $query->header(
            -type   => 'text/plain',
            -status => '400 Bad Request'
        );
        print "userId is undefined..";
        exit 0;
    }

    my $dateDue = $query->param('desiredDateDue');
    if ($dateDue) {    # Need to restrict maximal DateDue ..
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

        $dateDue = Koha::DateUtils::dt_from_string($dateDue);
        $dateDue->set_hour(23);
        $dateDue->set_minute(59);
        if ($dateDue > $maxDateDue) {
            $dateDue = $maxDateDue;
        }    # Here is the restriction done ..

    }
    my ($okay, $error)
        = C4::Circulation::CanBookBeRenewed($userId, $itemId, '0');

    my $result;
    if ($okay) {
        $dateDue = C4::Circulation::AddRenewal($userId, $itemId, $branch,
            $dateDue);
        $result->{'dateDue'} = Koha::DateUtils::output_pref(
            {dt => $dateDue, as_due_date => 1});
    } else {
        $result->{'error'} = $error;
    }

    print $query->header(-type => 'text/plain', -charset => 'utf-8',);
    print to_json($result);

    exit 0;
}

1;
