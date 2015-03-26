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

sub requestItem {
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

    my $bibId   = $query->param('bibId');
    my $itemId  = $query->param('itemId');
    my $barcode = $query->param('barcode');

    if (defined $bibId and (defined $itemId or defined $barcode)) {
        print $query->header(
            -type   => 'text/plain',
            -status => '400 Bad Request'
        );
        print
            "Cannot process both bibId & itemId/barcode .. you have to choose only one";
        exit 0;
    }

    my $itemLevelHold = 1;
    unless (defined $itemId) {

        unless (defined $bibId) {
            unless (efined $barcode) {
                print $query->header(
                    -type   => 'text/plain',
                    -status => '400 Bad Request'
                );
                print "Param itemId or barcode is/are undefined\n";
                print "Neither param bibId is specified..";
                exit 0;
            } else {
                $itemId = C4::Items::GetItemnumberFromBarcode($barcode);
            }
        } else {
            # Here it is obvious it is requested Biblio level request ..
            my $canBeReserved
                = C4::Reserves::CanBookBeReserved($userId, $bibId);
            unless ($canBeReserved eq 'OK') {
                print $query->header(
                    -type   => 'text/plain',
                    -status => '409 Conflict'
                );
                print "Book cannot be reserved.. $canBeReserved";
                exit 0;
            }
            $itemLevelHold = 0;
        }
    }
    my $pickupLocation = $query->param('pickupLocation');

    if ($itemLevelHold) {
        my $canBeReserved = C4::Reserves::CanItemBeReserved($userId, $itemId);
        unless ($canBeReserved eq 'OK') {
            print $query->header(
                -type   => 'text/plain',
                -status => '409 Conflict'
            );
            print "Item cannot be reserved.. $canBeReserved";
            exit 0;
        }

        my $iteminfo = C4::Items::GetItem($itemId, undef, 1)
            ;    # Needed to determine whether itemId exits ..
        if (not defined $iteminfo) {
            print $query->header(
                -type   => 'text/plain',
                -status => '404 Not Found'
            );
            print "Item you want to request was not found..";
            exit 0;
        }
        if ($pickupLocation == '') {
            $pickupLocation = $iteminfo->{'holdingbranch'};
        }
        $bibId = $iteminfo->{'biblionumber'};
    } else {
        $pickupLocation = C4::Context->userenv->{'branch'};
        my $biblio = C4::Biblio::GetBiblio($bibId);
        if (not defined $biblio) {
            print $query->header(
                -type   => 'text/plain',
                -status => '404 Not Found'
            );
            print "Record you want to request was not found..";
            exit 0;
        }
    }

    my $requestType = $query->param('requestType')
        || 'Hold'
        ; # RequestType specifies if user wants the book now or doesn't mind to get into queue

    if (not $requestType =~ /^Loan$|^Hold$/i) {
        print $query->header(
            -type   => 'text/plain',
            -status => '400 Bad Request'
        );
        print "Param requestType not found/recognized..";
        exit 0;
    }
    # Process rank & whether user hasn't requested this item yet ..
    my $reserves = C4::Reserves::GetReservesFromBiblionumber(
        {biblionumber => $bibId, itemnumber => $itemId, all_dates => 1})
        ;    # Get rank ..

    foreach my $res (@$reserves) {
        if ($res->{borrowernumber} eq $userId) {
            print $query->header(
                -type   => 'text/plain',
                -status => '403 Forbidden'
            );
            print "User already has item requested";
            exit 0;
        }
    }

    my $rank = scalar(@$reserves);

    if ($requestType =~ '/^Loan$/' and $rank != 0) {
        print $query->header(
            -type   => 'text/plain',
            -status => '409 Conflict'
        );
        print "Loan not possible  .. holdqueuelength exists";
        exit 0;
    }

    my $expirationdate = $query->param('pickupExpiryDate');
    my $startdate      = $query->param('earliestDateNeeded');
    my $notes          = $query->param('notes') || 'Placed by svc/ncip';

    if ($itemLevelHold) {
        placeHold($query, $bibId, $itemId, $userId,
            $pickupLocation, $startdate, undef, $expirationdate, $notes,
            ++$rank, undef);
    } else {
        placeHold($query, $bibId, undef, $userId,
            $pickupLocation, $startdate, undef, $expirationdate, $notes,
            ++$rank, 'any');
    }
}

sub placeHold {
    my ($input,  $biblionumber, $checkitem, $borrowernumber,
        $branch, $startdate,    $title,     $expirationdate,
        $notes,  $rank,         $request
    ) = @_;
    my $borrower
        = C4::Members::GetMember('borrowernumber' => $borrowernumber);

    my $found;

    if (defined $checkitem) {
        my $item = C4::Items::GetItem($checkitem);

        unless (C4::Context->preference('ReservesNeedReturns')) {
            $rank = '0';
            $found = 'W' if $item->{'holdingbranch'} eq $branch;
        }
        $biblionumber = $item->{'biblionumber'};
    }
    if ($borrower) {
        my $reserveId = C4::Reserves::AddReserve(
            $branch,       $borrower->{'borrowernumber'},
            $biblionumber, 'a',
            undef,         $rank,
            $startdate,    $expirationdate,
            $notes,        $title,
            $checkitem,    $found
        );

        my $results;

# AddReserve currently doesn't return reserveId hence it's needed to parse it manually ..
        unless ($reserveId) {
            #Parse RequestId of the last requested item ..
            my @reserves = C4::Reserves::GetReservesFromBiblionumber(
                {   biblionumber => $biblionumber,
                    itemnumber   => $checkitem,
                    all_dates    => 1
                }
            );

            my $lastReserve = $reserves[-1][-1];

            if (    $lastReserve
                and $lastReserve->{'borrowernumber'} eq $borrowernumber)
            {
                $results->{'status'}    = 'ok';
                $results->{'requestId'} = $lastReserve->{'reserve_id'};
            } else {
                $results->{'status'} = 'failed';
            }

        } else {
            $results->{'status'}    = 'ok';
            $results->{'requestId'} = $reserveId;
        }

        print $input->header(
            -type    => 'text/plain',
            -charset => 'utf-8',
        );
        print to_json($results);
    } else {
        print $input->header(
            -type   => 'text/plain',
            -status => '404 Not Found'
        );
        print "User not found..";
    }
    exit 0;
}

1;
