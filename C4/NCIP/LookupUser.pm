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

use C4::Utils::DataTables qw( dt_get_params );
use C4::Utils::DataTables::Members qw( search );

sub lookupUser {
        my ( $params ) = @_;
        my $cgiInput = $params->{input};

        my $searchmember = $params->{userid};

        my %dt_params = dt_get_params($cgiInput);
        foreach (grep {$_ =~ /^mDataProp/} keys %dt_params) {
            $dt_params{$_} =~ s/^dt_//;
        }

        my $results;

        # Perform the patrons search
        $results = C4::Utils::DataTables::Members::search(
            {
                searchmember => $searchmember,
                firstletter => '',
                categorycode => '',
                branchcode => '',
                searchtype => '',
                searchfieldstype => "borrowernumber",
                dt_params => \%dt_params,
            }
        ) unless $results;

        return $results;
}

1;

