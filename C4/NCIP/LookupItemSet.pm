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

package C4::NCIP::LookupItemSet;

use Modern::Perl;

use JSON qw(to_json);

sub lookupItemSet {
    my $query = shift;

    my $bibId = $query->param('bibId');

    unless ($bibId) {
        print $query->header(
            -type   => 'text/plain',
            -status => '400 Bad Request'
        );
        print "Param bibId is undefined..";
        exit 0;
    }

    my $result;
	$result->{bibliodata} = parseBiblio($bibId);

    print $query->header(-type => 'text/plain', -charset => 'utf-8',);
    print to_json($result);
    exit 0;
}

sub parseBiblio {
    my $bibId = shift;
    my $data;
    return $data || 'not implemented yet ..';
}

1;
