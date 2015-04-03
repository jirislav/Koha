#!/usr/bin/perl

# Copyright 2013 BibLibre
#
# This file is part of Koha
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

package C4::NCIP::LookupUser;

use Modern::Perl;
use C4::NCIP::NcipUtils;

=head1 NAME

C4::NCIP::LookupUser - NCIP module for effective processing of LookupUser NCIP service

=head1 SYNOPSIS

  use C4::NCIP::LookupUser;

=head1 DESCRIPTION

        Info about NCIP and it's services can be found here: http://www.niso.org/workrooms/ncip/resources/

=cut

=head1 METHODS

=head2 lookupUser

        lookupUser($cgiInput)

        Expected input is as e.g. as follows:
	http://188.166.14.82:8080/cgi-bin/koha/svc/ncip?service=lookup_user&userId=3&loanedItemsDesired&requestedItemsDesired&userFiscalAccountDesired&notUserInfo
	or
	http://188.166.14.82:8080/cgi-bin/koha/svc/ncip?service=lookup_user&userId=3

        REQUIRED PARAMS:
        Param 'service=lookup_user' tells svc/ncip to forward the query here.
        Param 'userId=3' specifies borrowernumber to look for.

        OPTIONAL PARAMS:
	loanedItemsDesired specifies to include user's loaned items
	requestedItemsDesired specifies to include user's holds
	userFiscalAccountDesired specifies to inlude user's transactions
	notUserInfo specifies to omit looking up user's personal info as address, name etc.
=cut

sub lookupUser {
    my ($query) = @_;
    my $userId = $query->param('userId');
    C4::NCIP::NcipUtils::print400($query, "Param userId is undefined..")
        unless $userId;

    my $userData = parseUserData($userId);

    C4::NCIP::NcipUtils::print404($query, "User not found..")
        unless $userData;

    my $results;
    my $desiredSomething = 0;
    if (defined $query->param('loanedItemsDesired')) {
        $results->{'loanedItems'} = parseLoanedItems($userId);
        $desiredSomething = 1;
    }
    if (defined $query->param('requestedItemsDesired')) {
        my @reserves
            = C4::Reserves::GetReservesFromBorrowernumber($userId, undef);

        C4::NCIP::NcipUtils::clearEmptyKeysWithinArray(@reserves);

        $results->{'requestedItems'} = \@reserves;
        $desiredSomething = 1;
    }
    if (defined $query->param('userFiscalAccountDesired')) {
        $results->{'userFiscalAccount'} = parseUserFiscalAccount($userId);
        $desiredSomething = 1;
    }
    $results->{'userInfo'} = $userData
        unless $desiredSomething and defined $query->param('notUserInfo');

    C4::NCIP::NcipUtils::printJson($query, $results);
}

=head2 parseUserData
	
	parseUserData($borrowenumber)

	Returns hashref of user's personal data as they are in table borrowers
=cut

sub parseUserData {
    my ($userId) = @_;
    my $dbh      = C4::Context->dbh;
    my $sth      = $dbh->prepare("
        SELECT surname,
                firstname,
                title,
		othernames,
		streetnumber,
		address,
		address2,
		city,
		state,
		zipcode,
		country,
		email,
		phone,
		mobile,
		fax,
		emailpro,
		phonepro,
		B_streetnumber,
		B_address,
		B_address2,
		B_city,
		B_state,
		B_zipcode,
		B_country,
		B_email,
		B_phone,
		dateofbirth,
		branchcode,
		categorycode,
		dateenrolled,
		dateexpiry
        FROM borrowers
        WHERE borrowernumber = ?");
    $sth->execute($userId);
    return C4::NCIP::NcipUtils::clearEmptyKeys($sth->fetchrow_hashref);
}

=head2 parseLoanedItems

	parseLoanedItems($borrowernumber)

	Returns array of user's issues with only these keys: issuedate, date_due, itemnumber

=cut

sub parseLoanedItems {
    my ($userId) = @_;
    my $dbh      = C4::Context->dbh;
    my $sth      = $dbh->prepare("
        SELECT issuedate,
		date_due,
		itemnumber
        FROM issues
        WHERE borrowernumber = ?");
    $sth->execute($userId);

    return \@{$sth->fetchall_arrayref({})};
}

=head2 parseUserFiscalAccount

	parseUserFiscalAccount($borrowenumber)

	Returns array of user's accountlines with these keys: accountno, itemnumber, date, amount, description, note		

=cut

sub parseUserFiscalAccount {
    my ($userId) = @_;
    my $dbh      = C4::Context->dbh;
    my $sth      = $dbh->prepare("
        SELECT accountno,
		itemnumber,
		date,
		amount,
		description
        FROM accountlines
        WHERE borrowernumber = ?
	ORDER BY date desc,timestamp DESC");
    $sth->execute($userId);

    return \@{$sth->fetchall_arrayref({})};
}

1;

