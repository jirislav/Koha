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

use JSON qw(to_json);

use Modern::Perl;
use Koha::DateUtils;
use C4::Utils::DataTables;
use C4::Utils::DataTables::Members qw/search/;

sub lookupUser {
    my $query  = shift;
    my $userId = $query->param('userId');
    if ($userId eq '') {
        print $query->header(
            -type   => 'text/plain',
            -status => '400 Bad Request'
        );
        print "Param userId is undefined..";
        exit 0;
    }

    my $results;

    $results->{'userInfo'} = parseUserData(
        {   input  => $query,
            userId => $userId
        }
    );

    unless ($results->{'userInfo'}) {
        print $query->header(
            -type   => 'text/plain',
            -status => '404 Not Found'
        );
        print "User you were looking up was not found..";
        exit 0;
    }

    if (defined $query->param('loanedItemsDesired')) {
        $results->{'loanedItems'} = parseLoanedItems($userId);
    }
    if (defined $query->param('requestedItemsDesired')) {
        my @reserves
            = C4::Reserves::GetReservesFromBorrowernumber($userId, undef);
        $results->{'requestedItems'} = \@reserves;
    }
    if (defined $query->param('userFiscalAccountDesired')) {
        $results->{'userFiscalAccount'} = parseUserFiscalAccount($userId);
    }

    print $query->header(-type => 'text/plain', -charset => 'utf-8',);
    print to_json($results);
    exit 0;
}

sub parseUserData {
    my ($params) = @_;
    my $cgiInput = $params->{input};

    my $searchmember = $params->{userId};

    my %dt_params = C4::Utils::DataTables::dt_get_params($cgiInput);
    foreach (grep {$_ =~ /^mDataProp/} keys %dt_params) {
        $dt_params{$_} =~ s/^dt_//;
    }

    my $result;

    # Perform the patrons search;
    $result = C4::Utils::DataTables::Members::search(
        {   searchmember     => $searchmember,
            firstletter      => '',
            categorycode     => '',
            branchcode       => '',
            searchtype       => '',
            searchfieldstype => "borrowernumber",
            dt_params        => \%dt_params,
        }
    );

    return ${$result->{patrons}}[0];
}

sub parseLoanedItems {
    my $userId = shift;
    my $dbh    = C4::Context->dbh;
    my $query  = "
        SELECT issuedate,
		date_due,
		itemnumber		
        FROM issues
        WHERE issues.borrowernumber = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($userId);
    my @items;
    my $i = 0;

    while (my $data = $sth->fetchrow_hashref) {
        $items[$i++] = $data;
    }
	return \@items;
}

sub parseUserFiscalAccount {
    my $userId = shift;

    my (undef, $accts, undef) = C4::Members::GetMemberAccountRecords($userId);

    return $accts;
}

1;

