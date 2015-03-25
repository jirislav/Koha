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

package C4::NCIP::LookupItem;

use Modern::Perl;

use JSON qw(to_json);

sub lookupItem {
    my $query = shift;

    my $itemId  = $query->param('itemId');
    my $barcode = $query->param('barcode');

    unless (defined $itemId) {
        unless (defined $barcode) {
            print $query->header(
                -type   => 'text/plain',
                -status => '400 Bad Request'
            );
            print
                "Param itemId & barcode is undefined..\n Specify at least one of these";
            exit 0;
        } else {
            $itemId = C4::Items::GetItemnumberFromBarcode($barcode);
        }
    }

    my $iteminfo = C4::Items::GetItem($itemId, $barcode, undef);
    if (not defined $iteminfo) {
        print $query->header(
            -type   => 'text/plain',
            -status => '404 Not Found'
        );
        print "Item you are looking for was not found..";
        exit 0;
    }

    my $bibId = $iteminfo->{'biblioitemnumber'};

    my $result;

    if (   defined $query->param('holdQueueLengthDesired')
        or defined $query->param('circulationStatusDesired'))
    {

        my $holds = C4::Reserves::GetReservesFromBiblionumber(
            {   biblionumber => $bibId,
                itemnumber   => $itemId,
                all_dates    => 1
            }
        );
        if (defined $query->param('holdQueueLengthDesired')) {
            $result->{'holdQueueLength'} = scalar(@$holds);
        }
        if (defined $query->param('circulationStatusDesired')) {
            $result->{'circulationStatus'}
                = scalar(@$holds) == 0
                ? parseCirculationStatus($iteminfo)
                : 'On Loan';
        }
        if (defined $query->param('itemUseRestrictionTypeDesired')) {
            my $restrictions = parseItemUseRestrictions($iteminfo);
            unless (scalar @{$restrictions} == 0) {
                $result->{'itemUseRestrictions'} = $restrictions;
            }
        }
    }
    $result->{'item'} = parseItem($bibId, $itemId, $iteminfo);
    print $query->header(-type => 'text/plain', -charset => 'utf-8',);
    print to_json($result);
    exit 0;
}

sub parseItem {
    my $bibId  = shift;
    my $itemId = shift;
    my $item   = shift;
    my $result;

    $result->{itemId}           = $itemId;
    $result->{bibId}            = $bibId;
    $result->{barcode}          = $item->{barcode};
    $result->{location}         = $item->{location};
    $result->{agencyid}         = $item->{homebranch};
    $result->{mediumtype}       = $item->{itype};
    $result->{copynumber}       = $item->{copynumber};
    $result->{callnumber}       = $item->{itemcallnumber};
    $result->{biblioitemnumber} = $item->{biblioitemnumber};
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("
        SELECT biblioitems.volume,
                biblioitems.number,
                biblioitems.isbn,
                biblioitems.issn,
                biblioitems.publicationyear,
                biblioitems.publishercode,
                biblioitems.pages,
                biblioitems.size,
                biblioitems.place,
                biblioitems.agerestriction,
                biblio.author,
                biblio.title,
                biblio.unititle,
                biblio.notes,
                biblio.serial
        FROM biblioitems
        LEFT JOIN biblio ON biblio.biblionumber = biblioitems.biblionumber
        WHERE biblioitems.biblionumber = ?");
    $sth->execute($bibId);
    my $data = clearEmptyKeys($sth->fetchrow_hashref);

    return 'SQL query failed' unless $data;

    foreach my $key (keys $data) {
        $result->{$key} = $data->{$key};
    }

    $result = clearEmptyKeys($result);

    return $result || 'failed';
}

sub parseCirculationStatus {
    my $item = shift;
    if ($item->{datedue} or $item->{onloan}) {
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

sub clearEmptyKeys {
    my $hashref = shift;

    foreach my $key (keys $hashref) {
        delete $hashref->{$key} unless defined $hashref->{$key};
    }
    return $hashref;
}

1;
