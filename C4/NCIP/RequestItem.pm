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

package C4::NCIP::RequestItem;

use Modern::Perl;

use JSON qw(to_json);

sub requestItem {
    my $query  = shift;
    my $userid = $query->param('userId');
    if ($userid eq '') {
        print $query->header(
            -type   => 'text/plain',
            -status => '400 Bad Request'
        );
        print "Param userId is undefined..";
        exit 0;
    }

    my $bibid   = $query->param('bibid');
    my $itemid  = $query->param('itemid');
    my $barcode = $query->param('barcode');

    if (defined $bibid and (defined $itemid or defined $barcode)) {
        print $query->header(
            -type   => 'text/plain',
            -status => '400 Bad Request'
        );
        print
            "Cannot process both bibid & itemid/barcode .. you have to choose only one";
        exit 0;
    }

    my $itemLevelHold = 1;
    if (not defined $itemid or not is_integer($itemid)) {

        if (not defined $bibid) {
            if (not defined $barcode or not is_integer($barcode)) {
                print $query->header(
                    -type   => 'text/plain',
                    -status => '400 Bad Request'
                );
                print
                    "Param itemid or barcode is/are undefined or is/are not number(s)..\n";
                print "Neither param bibid is specified..";
                exit 0;
            } else {
                $itemid = C4::Items::GetItemnumberFromBarcode($barcode);
            }
        } else {
            $itemLevelHold = 0;
        }
    }
    my $pickupLocation = $query->param('pickupLocation');

    if ($itemLevelHold) {
        my $iteminfo = C4::Items::GetItem($itemid, undef, 1)
            ;    # Needed to determine whether itemId exits ..
        if (not defined $iteminfo) {
            print $query->header(
                -type   => 'text/plain',
                -status => '404 Not Found'
            );
            print "Item you want to request was not found..";
            exit 0;
        }
        if ($pickupLocation == '') {
            $pickupLocation = $iteminfo->{'holdingbranch'};
        }
        $bibid = $iteminfo->{'biblionumber'};
    } else {
        $pickupLocation = C4::Context->userenv->{'branch'};
        my $biblio = C4::Biblio::GetBiblio($bibid);
        if (not defined $biblio) {
            print $query->header(
                -type   => 'text/plain',
                -status => '404 Not Found'
            );
            print "Record you want to request was not found..";
            exit 0;
        }
    }

    my $requestType = $query->param('requestType')
        || 'Hold'
        ; # RequestType specifies if user wants the book now or doesn't mind to get into queue

    if (not $requestType =~ /^Loan$|^Hold$/i) {
        print $query->header(
            -type   => 'text/plain',
            -status => '400 Bad Request'
        );
        print "Param requestType not found/recognized..";
        exit 0;
    }
    # Process rank & whether user hasn't requested this item yet ..
    my $reserves = C4::Reserves::GetReservesFromBiblionumber(
        {biblionumber => $bibid, itemnumber => $itemid, all_dates => 1})
        ;    # Get rank ..

    foreach my $res (@$reserves) {
        if ($res->{borrowernumber} eq $userid) {
            print $query->header(
                -type   => 'text/plain',
                -status => '403 Forbidden'
            );
            print "User already has item requested";
            exit 0;
        }
    }

    my $rank = scalar(@$reserves);

    if ($requestType =~ '/^Loan$/' and $rank != 0) {
        print $query->header(
            -type   => 'text/plain',
            -status => '409 Conflict'
        );
        print "Loan not possible  .. holdqueuelength exists";
        exit 0;
    }

    my $expirationdate = $query->param('pickupExpiryDate');
    my $startdate      = $query->param('earliestDateNeeded');
    my $notes          = $query->param('notes');

    my $title = $query->param('title');

    if ($itemLevelHold) {
        placeHold($query, $bibid, $itemid, $userid,
            $pickupLocation, $startdate, $title, $expirationdate, $notes,
            ++$rank, undef);
    } else {
        placeHold($query, $bibid, undef, $userid,
            $pickupLocation, $startdate, $title, $expirationdate, $notes,
            ++$rank, 'Any');
    }
}

sub placeHold {    # FIXME: I need to refactor :'(
    my ($input,  $biblionumber, $checkitem, $borrowernumber,
        $branch, $startdate,    $title,     $expirationdate,
        $notes,  $rankrequest,  $request
    ) = @_;
    my @rank     = $rankrequest;
    my $borrower = C4::Members::GetMember('borrowernumber' => $borrowernumber);
    my @bibitems = '';

    my $multi_hold    = '';
    my $biblionumbers = $biblionumber . '/';
    my $bad_bibs      = '';
    my @reqbib        = '';
    my %bibinfos      = ();
    my @biblionumbers = split '/', $biblionumbers;
    foreach my $bibnum (@biblionumbers) {
        my %bibinfo = ();
        $bibinfo{title}    = $input->param("title_$bibnum");
        $bibinfo{rank}     = $input->param("rank_$bibnum");
        $bibinfos{$bibnum} = \%bibinfo;
    }

    my $found;

# if we have an item selectionned, and the pickup branch is the same as the holdingbranch
# of the document, we force the value $rank and $found .
    if ($checkitem ne '') {
        $rank[0] = '0' unless C4::Context->preference('ReservesNeedReturns');
        my $item = $checkitem;
        $item = C4::Items::GetItem($item);
        if ($item->{'holdingbranch'} eq $branch) {
            $found = 'W'
                unless C4::Context->preference('ReservesNeedReturns');
        }
    }
    if ($borrower) {
        foreach my $biblionumber (keys %bibinfos) {
            my $count = @bibitems;
            @bibitems = sort @bibitems;
            my $i2 = 1;
            my @realbi;
            $realbi[0] = $bibitems[0];
            for (my $i = 1; $i < $count; $i++) {
                my $i3 = $i2 - 1;
                if ($realbi[$i3] ne $bibitems[$i]) {
                    $realbi[$i2] = $bibitems[$i];
                    $i2++;
                }
            }
            my $const;

            if ($checkitem ne '') {
                my $item = C4::Items::GetItem($checkitem);
                if ($item->{'biblionumber'} ne $biblionumber) {
                    $biblionumber = $item->{'biblionumber'};
                }
            }

            if ($multi_hold) {
                my $bibinfo = $bibinfos{$biblionumber};
                C4::Reserves::AddReserve(
                    $branch,         $borrower->{'borrowernumber'},
                    $biblionumber,   'a',
                    [$biblionumber], $bibinfo->{rank},
                    $startdate,      $expirationdate,
                    $notes,          $bibinfo->{title},
                    $checkitem,      $found
                );
            } else {
                if ($input->param('request') eq 'any') {
                    # place a request on 1st available
                    C4::Reserves::AddReserve(
                        $branch,       $borrower->{'borrowernumber'},
                        $biblionumber, 'a',
                        \@realbi,      $rank[0],
                        $startdate,    $expirationdate,
                        $notes,        $title,
                        $checkitem,    $found
                    );
                } elsif ($reqbib[0] ne '') {
                    C4::Reserves::AddReserve(
                        $branch,       $borrower->{'borrowernumber'},
                        $biblionumber, 'o',
                        \@reqbib,      $rank[0],
                        $startdate,    $expirationdate,
                        $notes,        $title,
                        $checkitem,    $found
                    );
                } else {
                    C4::Reserves::AddReserve(
                        $branch,       $borrower->{'borrowernumber'},
                        $biblionumber, 'a',
                        \@realbi,      $rank[0],
                        $startdate,    $expirationdate,
                        $notes,        $title,
                        $checkitem,    $found
                    );
                }
            }
        }

        #Parse RequestId of the last requested item ..
        my @reserves = C4::Reserves::GetReservesFromBiblionumber(
            {   biblionumber => $biblionumber,
                itemnumber   => $checkitem,
                all_dates    => 1
            }
        );

        my $lastReserve = $reserves[-1][-1];

        my $results;
        if (    defined $lastReserve
            and $lastReserve->{'priority'} eq $rankrequest
            and $lastReserve->{'borrowernumber'} eq $borrowernumber)
        {
            $results->{'status'}    = 'ok';
            $results->{'requestId'} = $lastReserve->{'reserve_id'};
        } else {
            $results->{'status'} = 'failed';
        }
        #	$results->{'reserves'} = $reserves[-1];

        print $input->header(
            -type    => 'text/plain',
            -charset => 'utf-8',
        );
        print to_json($results);
    } else {
        print $input->header(
            -type   => 'text/plain',
            -status => '404 Not Found'
        );
        print "User not found..";
    }
    exit 0;
}

sub is_integer {
    defined $_[0] && $_[0] =~ /^[+-]?\d+$/;
}

1;
