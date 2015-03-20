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

package C4::NCIP::RequestItem;

use Modern::Perl;

use JSON qw(to_json);
use C4::Biblio;
use C4::Items;
use C4::Output;
use C4::Reserves;
use C4::Circulation;
use C4::Members;

sub placeHold {
    my ($params) = @_;
    my $input = $params->{input};

    my $bibid       = $params->{bibid};
    my $itemid      = $params->{itemid};
    my $userid      = $params->{userid};
    my $requestType = $params->{requestType};

    my $branch         = $params->{pickup};
    my $startdate      = $params->{earliestDateNeeded} || '';
    my $borrower       = GetMember('borrowernumber' => $userid);
    my $expirationdate = $input->param('pickupExpiryDate'); #FIXME: Cannot forward this properly .. 

    my $found;
    my $notes;
    my $title;

    my $results;
    if ($borrower) {
        if (not defined $bibid or not defined $branch) {
            my $item = GetItem($itemid);
            if (not defined $branch) {
                $branch = $item->{'holdingbranch'};
            }
            if (not defined $bibid) {
                $bibid = $item->{'biblionumber'};
            }
        }

        my $reserves = GetReservesFromBiblionumber(
            {biblionumber => $bibid, itemnumber => $itemid, all_dates => 1})
            ;    # Get rank ..

	if($requestType =~ '/^Loan$/' and scalar ( @$reserves ) != 0) {
		print $input->header(-type => 'text/plain',-charset => 'utf-8', -status => '409 Conflict');
		print "Loan not possible  .. holdqueuelength exists";
		exit 0;
	}

        foreach my $res (@$reserves) {
            if ($res->{borrowernumber} eq $userid) {
		print $input->header(-type => 'text/plain',-charset => 'utf-8', -status => '403 Forbidden');
                print "User already has item requested";
		exit 0;
            }
        }
        my $rank = scalar(@$reserves);

        my $requestId = AddReserve(
            $branch,    $borrower->{'borrowernumber'},
            $bibid,     'a',
            [$bibid],   ++$rank,
            $startdate, $expirationdate,
            $notes,     $title,
            $itemid,    $found
        );

	if (not defined $requestId) {
        	my @reserves = GetReservesFromBiblionumber({biblionumber => $bibid, itemnumber => $itemid, all_dates => 1});# Get rank ..
		$requestId = $reserves[-1][-1]->{'reserve_id'};
	}

	print $input->header(-type => 'text/plain',-charset => 'utf-8', -status => '201 Created');
	$results->{'response'} = $expirationdate;
    	print to_json($results);
    } else {
	print $input->header(-type => 'text/plain',-charset => 'utf-8', -status => '404 Not Found');
        print "User not found..";
    }
    exit 0;
}

1;
