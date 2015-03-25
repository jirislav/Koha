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

use JSON qw(to_json);

sub lookupRequest {
    my $query     = shift;
    my $requestId = $query->param('requestId');

    my $result;
    if (defined $requestId) {
        $result = C4::Reserves::GetReserve($requestId);
    } else {
        my $userId = $query->param('userId');
        my $itemId = $query->param('itemId');

        if (defined $userId and defined $itemId) {
            $result = C4::Reserves::GetReserveFromBorrowernumberAndItemnumber($userId, $itemId);
        } else {
            print $query->header(
                -type   => 'text/plain',
                -status => '400 Bad Request'
            );
            print
                'You have to specify \'requestId\' or both \'userId\' & \'itemId\'..';
            exit 0;
        }
    }
    if (not defined $result) {
        print $query->header(
            -type   => 'text/plain',
            -status => '404 Not Found'
        );
        print "Request not found..";
        exit 0;
    }
    print $query->header(-type => 'text/plain', -charset => 'utf-8',);
    print to_json($result);

    exit 0;
}
1;
