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
use C4::NCIP::NcipUtils;

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
    # Parse Bibliographic data
    $result->{bibData} = parseBiblio($bibId);

    my $circStatusDesired = defined $query->param('circulationStatusDesired');

    # Parse Items within BibRecord ..
    $result->{items} = parseItems($bibId, $circStatusDesired);

    my $holdQueueDesired = defined $query->param('holdQueueLengthDesired');
    my $itemRestrictsDesired
        = defined $query->param('itemUseRestrictionTypeDesired');

    my $count = scalar @{$result->{items}};

    $result->{itemsCount} = $count;

    for (my $i = 0; $i < $count; ++$i) {
        my $item = ${$result->{items}}[$i];
        if ($holdQueueDesired or $circStatusDesired) {

            my $holds = C4::Reserves::GetReservesFromBiblionumber(
                {   biblionumber => $bibId,
                    itemnumber   => $item->{itemnumber},
                    all_dates    => 1
                }
            );
            if ($holdQueueDesired) {
                $item->{'holdQueueLength'} = scalar(@$holds);
            }
            if ($circStatusDesired) {
                $item->{'circulationStatus'}
                    = C4::NCIP::NcipUtils::parseCirculationStatus($item,
                    scalar @$holds);

                # Delete keys not needed anymore
                delete $item->{onloan};
                delete $item->{itemlost};
                delete $item->{withdrawn};
                delete $item->{damaged};
            }
        }
        if ($itemRestrictsDesired) {
            my $restrictions
                = C4::NCIP::NcipUtils::parseItemUseRestrictions($item);
            unless (scalar @{$restrictions} == 0) {
                $item->{'itemUseRestrictions'} = $restrictions;
            }
        }
        delete $item->{notforloan};
    }
    print $query->header(-type => 'text/plain', -charset => 'utf-8',);
    print to_json($result);
    exit 0;
}

sub parseBiblio {
    my $bibId = shift;
    my $dbh   = C4::Context->dbh;
    my $sth   = $dbh->prepare("
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
    my $data = C4::NCIP::NcipUtils::clearEmptyKeys($sth->fetchrow_hashref);

    return $data || 'SQL query failed..';
}

sub parseItems {
    my ($bibId, $circStatusDesired) = @_;
    my $dbh   = C4::Context->dbh;
    my $query = "
	SELECT itemnumber,
		barcode,
		homebranch,
		notforloan,
		itemcallnumber,
		restricted,
		holdingbranch,
		location,
		ccode,
		materials,
		copynumber";
    if ($circStatusDesired) {
        $query .= ",
		onloan,
		itemlost,
		withdrawn,
		damaged";
    }
    $query .= "
		FROM items
		WHERE items.biblionumber = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($bibId);
    my @items;
    my $i = 0;
    while (my $data
        = C4::NCIP::NcipUtils::clearEmptyKeys($sth->fetchrow_hashref))
    {
        $items[$i++] = $data;
    }

    return \@items;
}

1;
