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

package C4::NCIP::CancelRequestItem;

use Modern::Perl;

sub cancelRequestItem {
    my ($query)   = @_;
    my $userId    = $query->param('userId');
    my $itemId    = $query->param('itemId');
    my $requestId = $query->param('requestId');
    my ($result, $reserve);
    if (defined $userId and defined $itemId) {
        $reserve
            = C4::Reserves::GetReserveFromBorrowernumberAndItemnumber($userId,
            $itemId);

    } elsif (defined $userId and defined $requestId) {
        $reserve = C4::Reserves::GetReserve($requestId);
    } else {
        C4::NCIP::NcipUtils::print400($query,
            'You have to specify either both \'userId\' & \'itemId\' or both \'userId\' & \'requestId\'..'
        );
    }

    C4::NCIP::NcipUtils::print404($query, "Request not found..")
        unless $reserve;

    C4::NCIP::NcipUtils::print403($query,
        'Request doesn\'t belong to this patron ..')
        unless $reserve->{'borrowernumber'} eq $userId;

    C4::Reserves::CancelReserve($reserve);

    $result->{'userId'}    = $reserve->{borrowernumber};
    $result->{'itemId'}    = $reserve->{itemnumber};
    $result->{'requestId'} = $reserve->{reserve_id};
    $result->{'status'}    = 'cancelled';

    C4::NCIP::NcipUtils::printJson($query, $result);
}

1;
