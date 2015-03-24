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
use C4::Biblio;
use C4::Items;
use C4::Output;
use C4::Reserves;
use C4::Circulation;
use C4::Members;

sub placeHold { # FIXME: I need to refactor :'(
    my ($input,  $biblionumber, $checkitem, $borrowernumber,
        $branch, $startdate,    $title,     $expirationdate,
        $notes,  $rankrequest,  $request
    ) = @_;
    my @rank = $rankrequest;
    my $borrower = GetMember('borrowernumber' => $borrowernumber);
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
        $item = GetItem($item);
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
                my $item = GetItem($checkitem);
                if ($item->{'biblionumber'} ne $biblionumber) {
                    $biblionumber = $item->{'biblionumber'};
                }
            }

            if ($multi_hold) {
                my $bibinfo = $bibinfos{$biblionumber};
                AddReserve(
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
                    AddReserve(
                        $branch,       $borrower->{'borrowernumber'},
                        $biblionumber, 'a',
                        \@realbi,      $rank[0],
                        $startdate,    $expirationdate,
                        $notes,        $title,
                        $checkitem,    $found
                    );
                } elsif ($reqbib[0] ne '') {
                    AddReserve(
                        $branch,       $borrower->{'borrowernumber'},
                        $biblionumber, 'o',
                        \@reqbib,      $rank[0],
                        $startdate,    $expirationdate,
                        $notes,        $title,
                        $checkitem,    $found
                    );
                } else {
                    AddReserve(
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
        my @reserves = GetReservesFromBiblionumber(
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

1;
