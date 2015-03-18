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

use Koha::DateUtils;

use C4::Utils::DataTables qw( dt_get_params );
use C4::Utils::DataTables::Members qw( search );

use C4::Biblio qw(GetMarcBiblio GetFrameworkCode GetRecordValue );
use C4::Circulation qw(GetIssuingCharges CanBookBeRenewed GetRenewCount GetSoonestRenewDate);
use C4::Koha qw(GetAuthorisedValueByCode);
use C4::Context;
use C4::Circulation qw(GetTransfers);

sub lookupUser {
	my ( $params ) = @_;
	my $cgiInput = $params->{input};

	my $searchmember = $params->{userid};

	my %dt_params = dt_get_params($cgiInput);
	foreach (grep {$_ =~ /^mDataProp/} keys %dt_params) {
	    $dt_params{$_} =~ s/^dt_//;
	}

	my $results;

	# Perform the patrons search;
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

sub parseLoanedItems {
	my ( $params ) = @_;
        my $input = $params->{input};


	my @borrowernumber   = $params->{'userid'};
	my $offset           = $params->{'offset'};
	my $results_per_page = $params->{'size'} || -1;

	$results_per_page = undef if ( $results_per_page == -1 );

	my @parameters;
	my $sql = '
	    SELECT
		issuedate,
		date_due,
		date_due < now() as date_due_overdue,
		issues.timestamp,

		onsite_checkout,

		biblionumber,
		biblio.title,
		author,

		itemnumber,
		barcode,
		itemnotes,
		itemcallnumber,
		replacementprice,

		issues.branchcode,
		branchname,

		items.itype,
		itemtype_item.description AS itype_description,
		biblioitems.itemtype,
		itemtype_bib.description AS itemtype_description,

		borrowernumber,
		surname,
		firstname,
		cardnumber,

		itemlost,
		damaged,

		DATEDIFF( issuedate, CURRENT_DATE() ) AS not_issued_today
	    FROM issues
		LEFT JOIN items USING ( itemnumber )
		LEFT JOIN biblio USING ( biblionumber )
		LEFT JOIN biblioitems USING ( biblionumber )
		LEFT JOIN borrowers USING ( borrowernumber )
		LEFT JOIN branches ON ( issues.branchcode = branches.branchcode )
		LEFT JOIN itemtypes itemtype_bib ON ( biblioitems.itemtype = itemtype_bib.itemtype )
		LEFT JOIN itemtypes itemtype_item ON ( items.itype = itemtype_item.itemtype )
	    WHERE borrowernumber = ?
	';

	push( @parameters, @borrowernumber );

	$sql .= " ORDER BY issuedate desc ";

	my $dbh = C4::Context->dbh();
	my $sth = $dbh->prepare($sql);
	$sth->execute(@parameters);

	my $item_level_itypes = C4::Context->preference('item-level_itypes');

	my @checkouts_today;
	my @checkouts_previous;
	while ( my $c = $sth->fetchrow_hashref() ) {
	    my ($charge) = GetIssuingCharges( $c->{itemnumber}, $c->{borrowernumber} );

	    my ( $can_renew, $can_renew_error ) =
	      CanBookBeRenewed( $c->{borrowernumber}, $c->{itemnumber} );
	    my $can_renew_date =
	      $can_renew_error && $can_renew_error eq 'too_soon'
	      ? output_pref(
		{
		    dt => GetSoonestRenewDate( $c->{borrowernumber}, $c->{itemnumber} ),
		    as_due_date => 1
		}
	      )
	      : undef;

	    my ( $renewals_count, $renewals_allowed, $renewals_remaining ) =
	      GetRenewCount( $c->{borrowernumber}, $c->{itemnumber} );

	    my $checkout = {
		DT_RowId   => $c->{itemnumber} . '-' . $c->{borrowernumber},
		title      => $c->{title},
		author     => $c->{author},
		barcode    => $c->{barcode},
		itemtype   => $item_level_itypes ? $c->{itype} : $c->{itemtype},
		itemtype_description => $item_level_itypes ? $c->{itype_description} : $c->{itemtype_description},
		itemnotes  => $c->{itemnotes},
		branchcode => $c->{branchcode},
		branchname => $c->{branchname},
		itemcallnumber => $c->{itemcallnumber}   || q{},
		charge         => $charge,
		price          => $c->{replacementprice} || q{},
		can_renew      => $can_renew,
		can_renew_error     => $can_renew_error,
		can_renew_date      => $can_renew_date,
		itemnumber          => $c->{itemnumber},
		borrowernumber      => $c->{borrowernumber},
		biblionumber        => $c->{biblionumber},
		issuedate           => $c->{issuedate},
		date_due            => $c->{date_due},
		date_due_overdue    => $c->{date_due_overdue} ? JSON::true : JSON::false,
		timestamp           => $c->{timestamp},
		onsite_checkout         => $c->{onsite_checkout},
		renewals_count      => $renewals_count,
		renewals_allowed    => $renewals_allowed,
		renewals_remaining  => $renewals_remaining,
		issuedate_formatted => output_pref(
		    {
			dt          => dt_from_string( $c->{issuedate} ),
			as_due_date => 1
		    }
		),
		date_due_formatted => output_pref(
		    {
			dt          => dt_from_string( $c->{date_due} ),
			as_due_date => 1
		    }
		),
		subtitle => GetRecordValue(
		    'subtitle',
		    GetMarcBiblio( $c->{biblionumber} ),
		    GetFrameworkCode( $c->{biblionumber} )
		),
		lost => $c->{itemlost} ? GetAuthorisedValueByCode( 'LOST', $c->{itemlost} ) : undef,
		damaged => $c->{damaged} ? GetAuthorisedValueByCode( 'DAMAGED', $c->{damaged} ) : undef,
		borrower => {
		    surname    => $c->{surname},
		    firstname  => $c->{firstname},
		    cardnumber => $c->{cardnumber},
		},
		issued_today => !$c->{not_issued_today},
	    }; 

	    if ( $c->{not_issued_today} ) {
		push( @checkouts_previous, $checkout );
	    }
	    else {
		push( @checkouts_today, $checkout );
	    }
	}

	@checkouts_today = reverse(@checkouts_today)
	  if ( C4::Context->preference('todaysIssuesDefaultSortOrder') eq 'desc' );
	@checkouts_previous = reverse(@checkouts_previous)
	  if ( C4::Context->preference('previousIssuesDefaultSortOrder') eq 'desc' );

	my @checkouts = ( @checkouts_today, @checkouts_previous );

	my $data;
	$data->{'iTotalRecords'}        = scalar @checkouts;
	$data->{'iTotalDisplayRecords'} = scalar @checkouts;
	$data->{'sEcho'}                = $input->param('sEcho') || undef;
	$data->{'aaData'}               = \@checkouts;
	return $data;

}

sub parseRequestedItems {
        my ( $params ) = @_;
        my $input = $params->{input};

	my $branch	     = $params->{branch};
        my $borrowernumber   = $params->{userid};
        my $offset           = $params->{offset};
        my $results_per_page = $params->{size} || -1;

        $results_per_page = undef if ( $results_per_page == -1 );
	
	my $schema = Koha::Database->new()->schema();

	my $holds_rs = $schema->resultset('Reserve')->search(
	    { borrowernumber => $borrowernumber },
	    {
	        prefetch => { 'item' => 'biblio' },
	        order_by => { '-desc' => 'reservedate' }
	    }
	);
	

	my $borrower;
	my @holds;
	while ( my $h = $holds_rs->next() ) {
	    my $item = $h->item();

	    my $biblionumber = $h->biblio()->biblionumber();

	    my $hold = {
		DT_RowId       => $h->reserve_id(),
		biblionumber   => $biblionumber,
		title          => $h->biblio()->title(),
		author         => $h->biblio()->author(),
		reserve_id     => $h->reserve_id(),
		reservedate    => $h->reservedate(),
		expirationdate => $h->expirationdate(),
		suspend        => $h->suspend(),
		suspend_until  => $h->suspend_until(),
		found          => $h->found(),
		waiting        => $h->found() eq 'W',
		waiting_at     => $h->branchcode()->branchname(),
		waiting_here   => $h->branchcode()->branchcode() eq $branch,
		priority       => $h->priority(),
		subtitle       => GetRecordValue(
		    'subtitle', GetMarcBiblio($biblionumber),
		    GetFrameworkCode($biblionumber)
		),
		reservedate_formatted => $h->reservedate() ? output_pref(
		    { dt => dt_from_string( $h->reservedate() ), dateonly => 1 }
		  )
		: q{},
		suspend_until_formatted => $h->suspend_until() ? output_pref(
		    { dt => dt_from_string( $h->suspend_until() ), dateonly => 1 }
		  )
		: q{},
		expirationdate_formatted => $h->expirationdate() ? output_pref(
		    { dt => dt_from_string( $h->expirationdate() ), dateonly => 1 }
		  )
		: q{},
	    };

	    $hold->{transfered}     = 0;
	    $hold->{not_transfered} = 0;

	    if ($item) {
		$hold->{itemnumber}     = $item->itemnumber();
		$hold->{barcode}        = $item->barcode();
		$hold->{itemtype}       = $item->effective_itemtype();
		$hold->{itemcallnumber} = $item->itemcallnumber() || q{};

		my ( $transferred_when, $transferred_from, $transferred_to ) =
		  GetTransfers( $item->itemnumber() );
		if ($transferred_when) {
		    $hold->{color}       = 'transferred';
		    $hold->{transferred} = 1;
		    $hold->{date_sent} = output_pref( dt_from_string($transferred_when) );
		    $hold->{from_branch} = GetBranchName($transferred_from);
		}
		elsif ( $item->holdingbranch()->branchcode() ne
		    $h->branchcode()->branchcode() )
		{
		    $hold->{not_transferred}    = 1;
		    $hold->{not_transferred_by} = $h->item()->holdingbranch()->branchname();
		}
	    }

	    push( @holds, $hold );
	}
	my $data;
	$data->{'iTotalRecords'}        = scalar @holds;
	$data->{'iTotalDisplayRecords'} = scalar @holds;
	$data->{'sEcho'}                = $input->param('sEcho') || undef;
	$data->{'aaData'}               = \@holds;
	return $data;
}

sub parseUserFiscalAccount {
        my ( $params ) = @_;
        my $input = $params->{input};
	# TODO: No svc doing this has been implemented, thus it is needed to create custom SQL query ..

        my @borrowernumber   = $params->{'userid'};
        my $offset           = $params->{'offset'};
        my $results_per_page = $params->{'size'} || -1;

        $results_per_page = undef if ( $results_per_page == -1 );
}

1;

