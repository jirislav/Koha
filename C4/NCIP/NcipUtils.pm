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

package C4::NCIP::NcipUtils;

use Modern::Perl;

sub clearEmptyKeys {
    my $hashref = shift;

    return undef unless $hashref;

    foreach my $key (keys $hashref) {
        delete $hashref->{$key} unless $hashref->{$key};
    }

    return $hashref;

}

sub parseCirculationStatus {
    my ($item, $holds) = @_;

    if ($item->{datedue} or $item->{onloan} or $holds != 0) {
        return 'On Loan';
    }
    if ($item->{transfertwhen}) {
        return 'In Transit Between Library Locations';
    }
    if (   $item->{notforloan_per_itemtype}
        or $item->{itemlost}
        or $item->{withdrawn}
        or $item->{damaged})
    {
        return 'Not Available';
    }

    return 'Available On Shelf';
}

sub parseItemUseRestrictions {
# Possible standardized values can be found here:
# https://code.google.com/p/xcncip2toolkit/source/browse/core/trunk/service/src/main/java/org/extensiblecatalog/ncip/v2/service/Version1ItemUseRestrictionType.java

    my $item = shift;
    my @toReturn;
    my $i = 0;
    if ($item->{notforloan}) {
        $toReturn[$i++] = 'In Library Use Only';
    }
    return \@toReturn;
}

1;
