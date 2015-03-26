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

sub lookupItemSet {
    my ($query) = @_;

    my $bibId = $query->param('bibId');

    C4::NCIP::NcipUtils::print400($query, "Param bibId is undefined..")
        unless $bibId;

    my $result;

    my $circStatusDesired = defined $query->param('circulationStatusDesired');

    # Parse Items within BibRecord ..
    $result->{items} = parseItems($bibId, $circStatusDesired);

    C4::NCIP::NcipUtils::print404($query, "Biblio not found..")
        if scalar @{$result->{items}} == 0;

    my $holdQueueDesired = defined $query->param('holdQueueLengthDesired');
    my $itemRestrictsDesired
        = defined $query->param('itemUseRestrictionTypeDesired');

    my $count = scalar @{$result->{items}};

    $result->{itemsCount} = $count;

    for (my $i = 0; $i < $count; ++$i) {
        my $item = ${$result->{items}}[$i];
        if ($holdQueueDesired or $circStatusDesired) {

            my $holds = C4::Reserves::GetReserveCountFromItemnumber(
                $item->{itemnumber});

            if ($holdQueueDesired) {
                $item->{'holdQueueLength'} = $holds;
            }
            if ($circStatusDesired) {
                $item->{'circulationStatus'}
                    = C4::NCIP::NcipUtils::parseCirculationStatus($item,
                    $holds);

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
    my $desiredSomething
        = $holdQueueDesired
        or $itemRestrictsDesired
        or $circStatusDesired;

    $result->{bibInfo} = parseBiblio($bibId)
        unless $desiredSomething and defined $query->param('notBibInfo');

    C4::NCIP::NcipUtils::printJson($query, $result);
}

sub parseBiblio {
    my ($bibId) = @_;
    my $dbh     = C4::Context->dbh;
    my $sth     = $dbh->prepare("
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
