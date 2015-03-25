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
    my $bibid = $query->param('bibid');
    if (defined $bibid) {
        fetch_marc_biblio($query, $bibid);
        exit 0;
    }

    my $itemid  = $query->param('itemid');
    my $barcode = $query->param('barcode');

    unless (defined $itemid) {
        unless (defined $barcode) {
            print $query->header(
                -type   => 'text/plain',
                -status => '400 Bad Request'
            );
            print
                "Param itemid & barcode is undefined..\n Specify at least one of these";
            exit 0;
        } else {
            $itemid = C4::Items::GetItemnumberFromBarcode($barcode);
        }
    }

    my $iteminfo = C4::Items::GetItem($itemid, undef, 1);
    if (not defined $iteminfo) {
        print $query->header(
            -type   => 'text/plain',
            -status => '404 Not Found'
        );
        print "Item you are looking for was not found..";
        exit 0;
    }

    my $bibid = $iteminfo->{'biblioitemnumber'};

    if (   defined $query->param('holdQueueLengthDesired')
        or defined $query->param('circulationStatusDesired'))
    {

        my $result;
        my $holds = C4::Reserves::GetReservesFromBiblionumber(
            {   biblionumber => $bibid,
                itemnumber   => $itemid,
                all_dates    => 1
            }
        );
        if (defined $query->param('holdQueueLengthDesired')) {
            $result->{'holdQueueLength'} = scalar(@$holds);
        }
        if (defined $query->param('circulationStatusDesired')) {
            if (scalar(@$holds) == 0)
            {    # FIXME this is wrong .. doesnt check number of holds ..
                $result->{'circulationStatus'}
                    = parse_circulation_status($iteminfo);
            } else {
                $result->{'circulationStatus'} = 'On Loan';
            }
        }
        if (defined $query->param('itemUseRestrictionTypeDesired')) {
            #TODO: Parse item's restrictions ..
        }
        print $query->header(-type => 'text/plain', -charset => 'utf-8',);
        print to_json($result);
    } elsif (not defined $query->param('getBiblioContext')) {
        fetch_marc_item($query, $bibid, $itemid);
    } else {
        fetch_marc_biblio($query, $bibid);
    }
    exit 0;
}

sub fetch_marc_biblio {
    my $query  = shift;
    my $bibid  = shift;
    my $record = C4::Biblio::GetMarcBiblio($bibid, 1);
    if (defined $record) {
        print $query->header(-type => 'text/xml', -charset => 'utf-8',);
        print $record->as_xml_record();
    } else {
        print $query->header(
            -type   => 'text/plain',
            -status => '404 Not Found'
        );
        print "Item you are looking for was not found..";
    }
}

sub fetch_marc_item {
    my $query  = shift;
    my $bibid  = shift;
    my $itemid = shift;
    my $record = C4::Items::GetMarcItem($bibid, $itemid);
    if (defined $record) {
        print $query->header(-type => 'text/xml', -charset => 'utf-8',);
        print $record->as_xml_record();
    } else {
        print $query->header(
            -type   => 'text/plain',
            -status => '404 Not Found'
        );
        print "Item you are looking for was not found..";
    }
}

sub parse_circulation_status {
    my $item = shift;
    if ($item->{datedue} or $item->{onloan}) {
        return 'On Loan';
    }
    if ($item->{transfertwhen}) {
        return 'In Transit Between Library Locations';
    }
    if (   $item->{itemnotforloan}
        or $item->{notforloan_per_itemtype}
        or $item->{itemlost}
        or $item->{withdrawn}
        or $item->{damaged})
    {
        return 'Not Available';
    }

    return 'Available On Shelf';
}

1;
