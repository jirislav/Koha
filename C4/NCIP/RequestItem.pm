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

sub requestItem {
    my $query  = shift;
    my $userId = $query->param('userId');

    C4::NCIP::NcipUtils::print400($query, "Param userId is undefined..")
        unless $userId;

    my $bibId   = $query->param('bibId');
    my $itemId  = $query->param('itemId');
    my $barcode = $query->param('barcode');

    C4::NCIP::NcipUtils::print400($query,
        "Cannot process both bibId & itemId/barcode .. you have to choose only one"
    ) if $bibId and ($itemId or $barcode);

    my $itemLevelHold = 1;
    unless ($itemId) {
        if ($bibId) {
            my $canBeReserved
                = C4::Reserves::CanBookBeReserved($userId, $bibId);

            print409($query, "Book cannot be reserved.. $canBeReserved")
                unless ($canBeReserved eq 'OK');

            $itemLevelHold = 0;
        } else {
            C4::NCIP::NcipUtils::print400($query,
                "Param bibId neither any of itemId and barcode is undefined")
                unless $barcode;

            $itemId = C4::Items::GetItemnumberFromBarcode($barcode);
        }
    }

    if ($itemLevelHold) {
        my $canBeReserved = C4::Reserves::CanItemBeReserved($userId, $itemId);

        C4::NCIP::NcipUtils::print409($query,
            "Item cannot be reserved.. $canBeReserved")
            unless $canBeReserved eq 'OK';

        $bibId = C4::Biblio::GetBiblionumberFromItemnumber($itemId);
    }

# RequestType specifies if user wants the book now or doesn't mind to get into queue
    my $requestType = $query->param('requestType');

    if ($requestType) {
        C4::NCIP::NcipUtils::print400($query,
            "Param requestType not recognized.. Can be \'Loan\' or \'Hold\'")
            if (not $requestType =~ /^Loan$|^Hold$/);
    } else {
        $requestType = 'Hold';
    }

    # Process rank & whether user hasn't requested this item yet ..
    my $reserves = C4::Reserves::GetReservesFromBiblionumber(
        {biblionumber => $bibId, itemnumber => $itemId, all_dates => 1});

    foreach my $res (@$reserves) {
        C4::NCIP::NcipUtils::print403($query,
            "User already has item requested")
            if $res->{borrowernumber} eq $userId;
    }

    my $rank = scalar(@$reserves);

    C4::NCIP::NcipUtils::print409($query,
        "Loan not possible  .. holdqueuelength exists")
        if $requestType ne 'Hold' and $rank != 0;

    my $expirationdate = $query->param('pickupExpiryDate');
    my $startdate      = $query->param('earliestDateNeeded');
    my $notes          = $query->param('notes') || 'Placed by svc/ncip';
    my $pickupLocation = $query->param('pickupLocation')
        || C4::Context->userenv->{'branch'};

    if ($itemLevelHold) {
        placeHold(
            $query,          $bibId,     $itemId,         $userId,
            $pickupLocation, $startdate, $expirationdate, $notes,
            ++$rank,         undef
        );
    } else {
        placeHold(
            $query,          $bibId,     undef,           $userId,
            $pickupLocation, $startdate, $expirationdate, $notes,
            ++$rank,         'any'
        );
    }
}

sub placeHold {
    my ($query,  $bibId,     $itemId,         $userId,
        $branch, $startdate, $expirationdate, $notes,
        $rank,   $request
    ) = @_;

    my $found;

    my $userExists = C4::Members::GetBorrowerCategorycode($userId);

    C4::NCIP::NcipUtils::print404($query, "User not found..")
        unless $userExists;

    my $reserveId = C4::Reserves::AddReserve(
        $branch, $userId, $bibId,     'a',
        undef,   $rank,   $startdate, $expirationdate,
        $notes,  undef,   $itemId,    $found
    );

    my $results;

    $results->{'status'}    = 'reserved';
    $results->{'bibId'}     = $bibId;
    $results->{'userId'}    = $userId;
    $results->{'requestId'} = $reserveId;

    $results->{'itemId'} = $itemId if $itemId;

    C4::NCIP::NcipUtils::printJson($query, $results);
}

1;
