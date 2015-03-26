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

package C4::NCIP::LookupRequest;

use Modern::Perl;

sub lookupRequest {
    my ($query) = @_;
    my $requestId = $query->param('requestId');

    my $result;
    if (defined $requestId) {
        $result = C4::Reserves::GetReserve($requestId);
    } else {
        my $userId = $query->param('userId');
        my $itemId = $query->param('itemId');

        C4::NCIP::NcipUtils::print400($query,
            'You have to specify \'requestId\' or both \'userId\' & \'itemId\'..'
        ) unless (defined $userId and defined $itemId);

        $result
            = C4::Reserves::GetReserveFromBorrowernumberAndItemnumber($userId,
            $itemId);
    }

    C4::NCIP::NcipUtils::print404($query, "Request not found..")
        unless $result;

    C4::NCIP::NcipUtils::clearEmptyKeys($result);

    C4::NCIP::NcipUtils::printJson($query, $result);
}
1;
