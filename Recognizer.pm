package Recognizer;

use Moose;
use List::Util qw/sum/;
use Data::Dumper;
use feature qw/say/;
use Utils;
use ReceiptImage;
use Letter;
use Template::Safeway;
use Receipt;

has 'img'      => (is => 'rw', isa => 'Object', required => 1);
has 'template' => (is => 'rw', isa => 'Object', required => 1);
has 'alphabet' => (is => 'rw', isa => 'Object', required => 1);

# ======== PUBLIC ========

sub recognize() {
	my ($self) = @_;
	my ($chars, $whites, $avghs) = $self->char_coords();
	say "===> chars, whites, avghs OK";
	my @raw_text = $self->find_text($chars, $whites);
	say "===> raw_text OK";
	my @preproc_lines = ();
	for (my $i = 0; $i < scalar @$chars; ++$i) {
		my $str = $raw_text[$i];
		my $coords = $chars->[$i];
		push @preproc_lines, {str => $str, coords => $coords}; 
	}
	say "===> preproc_lines OK";
	my $res = $self->find_products(@preproc_lines);
	return $res;
}

# returns an array of Letter objects like:
# ( {x=>1, y=>1, w=>3, h=>5, pix10x10=>'0101..1'}, ... , {...} )
#
sub char_coords() {
	my ($self) = @_;
	my @lines = Utils::get_lines_coord($self->img);
	my @chars = ();
	my @whites = ();
	my @avghs = ();
	for (my $i = 0; $i < scalar @lines; $i += 2) {
		my ($x0, $x1) = ($lines[$i], (-1) * $lines[$i+1]);
		my $letters_coord = get_letters_coord(
			$self->img, 
			$lines[$i], 
			(-1) * $lines[$i+1]
		);
		next if scalar @$letters_coord == 0;

		my $white = sum(map {$_->{w}} @$letters_coord)/(scalar @$letters_coord);
		push @whites, $white;
		my $avgh = sum(map {$_->{h}} @$letters_coord)/(scalar @$letters_coord);
		push @avghs, $avgh;

		for (my $j = 0; $j < scalar @$letters_coord; ++$j) {
			next if $letters_coord->[$j]{h} == 1 || $letters_coord->[$j]{w} == 1;
			my $pixels_10x10 = get_resized_pixels_10x10($self->img->Clone(), $letters_coord->[$j]);
			$letters_coord->[$j]->pix10x10($pixels_10x10);
	
		}
		push @chars, $letters_coord;
	}
	return (\@chars, \@whites, \@avghs);
}

sub find_text() {
	my ($self, $coords, $whites) = @_;
	my @raw_text = ();
	for (my $i = 0; $i < scalar @$coords; ++$i) {
		my $str = '';
		my $white = $whites->[$i];
		my $line = $coords->[$i];
		for (my $j = 0; $j < scalar @$line; ++$j) { 
			my $letter = $self->alphabet->which_symbol($line->[$j]{pix10x10});		
			if ($j > 0) {
				my $d = ($line->[$j]{x} - ($line->[$j-1]{x} + $line->[$j-1]{w})
					)/$white;
				$str .= " " x int(sprintf("%.1f", $d)) if (sprintf("%d", $d) > 1.05);
			}
			$str .=  $self->alphabet->word_to_sign($letter);
		}
		push @raw_text, $str;
	}
	return @raw_text;
}

sub find_products() {
	my ($self, @preproc_lines) = @_;
	my $width = $self->img->Get('columns');
	my @line_types = $self->template->line_types(@preproc_lines);
	say "in find prod " . Dumper(\@line_types);
	@line_types = $self->template->fill_line_types(\@line_types);
	
	say "in find prod (2)" . Dumper(\@line_types);

	my $i = 0;
	my $header = '';
	my $name = '';
	my $price = 0;
	my $regprice = 0;
	my $cardsavings = 0;
	my $qty = 0;
	my $creditcard = 0;
	my $change = 0;
	my $date = 0;
	my $tax = 0;
	my $product = undef;
	my @products = ();
	#my $total = 0;

	# final processing
	while($i < scalar @preproc_lines) {
		my @idx = $self->template->split_idx($preproc_lines[$i]);
		#say Dumper(\@idx);
		if ($line_types[$i] eq 'header') {
			$header = '';
			for my $s (@{$preproc_lines[$i]->{coords}}) {
				$header .= $self->alphabet->which_letter($s->{pix10x10});
			}
			$header = $self->template->get_valid_header($header);
			++$i;
			next;
		}
		elsif($line_types[$i] eq 'item') {
			push @products, $product if defined $product;
			$product = undef;
			$price = '';
			$name = '';
			my $idx_price = $idx[-1][1] - $idx[-1][0] + 1 > 1 
				? scalar @idx - 1 
				: scalar @idx - 2;
			my $has_qty = $preproc_lines[$i]->{str} =~ /QTY/i;
			for (my $j = 0; $j < scalar @idx; ++$j) {
				if ($j == $idx_price) {
					# parse price
					for (my $k = $idx[$j][0]; $k <= $idx[$j][1]; ++$k) {
						my $pix = $preproc_lines[$i]->{coords}[$k]{pix10x10};
						my $d = $self->alphabet->which_digit_or_point($pix);
						$price .= $self->alphabet->word_to_sign($d);
					}
				}
				elsif ($j < $idx_price) {
					# parse name
					for (my $k = $idx[$j][0]; $k <= $idx[$j][1]; ++$k) {
						my $pix = $preproc_lines[$i]->{coords}[$k]{pix10x10};
						$name .= $self->alphabet->which_letter_uc($pix);
					}
					$name .= " ";
				}
				# and don't parse the last letter after price (F/T)
			}
			$product = Product->new(
				name => $name, price => $price, category => lc($header));
			say "HEADER: " . $header;
			say "NAME: " . $name;
			say "PRICE: " . $price;
			say "------";
			++$i; 
			next;
		}
		elsif($line_types[$i] eq 'regprice') {
			$regprice = '';
			my $idx_price = $idx[-1][1] - $idx[-1][0] + 1 > 1 
				? scalar @idx - 1 
				: scalar @idx - 2;
			# parse regprice
			for (my $k = $idx[$idx_price][0]; $k <= $idx[$idx_price][1]; ++$k) {
				my $pix = $preproc_lines[$i]->{coords}[$k]{pix10x10};
				my $d = $self->alphabet->which_digit_or_point($pix);
				$regprice .= $self->alphabet->word_to_sign($d);
			}
			if (defined $product) {$product->regprice($regprice);}
			say "REGPRICE: " . $regprice;	
			++$i;
			next;
		}
		elsif($line_types[$i] eq 'cardsavings') {
			$cardsavings = '';
			my $idx_price = $idx[-1][1] - $idx[-1][0] + 1 > 1 
				? scalar @idx - 1 
				: scalar @idx - 2;
			# parse cardsavings
			for (my $k = $idx[$idx_price][0]; $k < $idx[$idx_price][1]; ++$k) {
				my $pix = $preproc_lines[$i]->{coords}[$k]{pix10x10};
				my $d = $self->alphabet->which_digit_or_point($pix);
				$cardsavings .= $self->alphabet->word_to_sign($d);
			}
			if (defined $product) {$product->discount($cardsavings);}
			say "CARDSAVINGS: " . $cardsavings;	
			++$i;
			next;
		}
		elsif($line_types[$i] eq 'creditcard') {
			$creditcard = '';
			my $idx_price = $idx[-1][1] - $idx[-1][0] + 1 > 1 
				? scalar @idx - 1 
				: scalar @idx - 2;
			# parse total price
			for (my $k = $idx[$idx_price][0]; $k <= $idx[$idx_price][1]; ++$k) {
				my $pix = $preproc_lines[$i]->{coords}[$k]{pix10x10};
				my $d = $self->alphabet->which_digit_or_point($pix);
				$creditcard .= $self->alphabet->word_to_sign($d);
			}
			say "TOTAL: " . $creditcard;	
			++$i;
			next;
		}
		elsif($line_types[$i] eq 'change') {
			$change = '';
			my $idx_price = $idx[-1][1] - $idx[-1][0] + 1 > 1 
				? scalar @idx - 1 
				: scalar @idx - 2;
			# parse total price
			for (my $k = $idx[$idx_price][0]; $k <= $idx[$idx_price][1]; ++$k) {
				my $pix = $preproc_lines[$i]->{coords}[$k]{pix10x10};
				my $d = $self->alphabet->which_digit_or_point($pix);
				$change .= $self->alphabet->word_to_sign($d);
			}
			say "CHANGE: " . $change;	
			++$i;
			next;
		}
		elsif($line_types[$i] eq 'date') {
			$date = '';
			for (my $j = 0; $j < 2; ++$j) {
				# parse date, then time 
				for (my $k = $idx[$j][0]; $k <= $idx[$j][1]; ++$k) {
					my $pix = $preproc_lines[$i]->{coords}[$k]{pix10x10};
					my $d .= $self->alphabet->which_digit_or_punct($pix);
					$date .= $self->alphabet->word_to_sign($d);
				}
				$date .= " ";
			}
			say "DATE: " . $date;
			++$i;
			next;
		}
		elsif($line_types[$i] eq 'taxbal') {
			push @products, $product if defined $product;
			$product = undef;
			++$i;
			next;
		}
		elsif($line_types[$i] eq 'tax') {
			push @products, $product if defined $product;
			$product = undef;
			$tax = '';
			my $idx_price = $idx[-1][1] - $idx[-1][0] + 1 > 1 
				? scalar @idx - 1 
				: scalar @idx - 2;
			# parse tax
			for (my $k = $idx[$idx_price][0]; $k <= $idx[$idx_price][1]; ++$k) {
				my $pix = $preproc_lines[$i]->{coords}[$k]{pix10x10};
				my $d = $self->alphabet->which_digit_or_point($pix);
				$tax .= $self->alphabet->word_to_sign($d);
			}
			say "TAX: " . $tax;
			++$i;
			next;
		}
		else {
			say "> OTHER";
			++$i; next;
		}
	}
	my $date1 = $self->template->str2utime($date); 
	my $receipt = Receipt->new({store => "Safeway", total => $creditcard,
		datetime => $date1, tax => $tax});
	return {products => \@products, receipt => $receipt};
}


# ======== PRIVATE ========

# returns a string
#
sub get_resized_pixels_10x10($$) {
	my ($img, $lc) = @_;
	$img->Crop(
		width  => $lc->w,
		height => $lc->h,
		x      => $lc->x,
		y      => $lc->y,
	);
	#$img->write("t/crop".++$ii. ".jpg");
	$img->Resize(geometry => "10x10!"); # ignore aspect ratio
	$img->BlackThreshold("50%");
	$img->WhiteThreshold("50%");
	#$img->write("t/".++$ii. ".jpg");
	my @pixels = $img->GetPixels(
		normalize => 1,
		map => 'I',
		x => 0,
		y => 0,
		width => 10,
		height => 10,
	);

	my $pix10x10 = join '', map {
		if ($_ > 0.9) { $_ = 1 }
		elsif ($_ < 0.1) { $_ = 0 }
	} @pixels;

	return $pix10x10;
}

# params:
# $img     - the original Image::Magick object we want to recognise
# $start_y - int, y-coordinate of the beginning of the text line
# $end_y   - int, y-coordinate of the end of the text line
# returns:
# array of objects of type Letter.
#
sub get_letters_coord($$$) {
	my ($img, $start_y, $end_y) = @_;
	my $w = $img->Get('columns');
	
	# 1. find columns 
	my @columns = ();
	# !!start with 1 because 0 causes error (if 0th column is not empty)
	for (my $i = 1; $i < $w; ++$i) {
		#read next column part
		my @pixels = $img->GetPixels(
			x     => $i,
			y     => $start_y,
			height => $end_y - $start_y + 1, 
			width => 1,
			map   => 'I',
			normalize => 1,
		);
		
		if (Utils::need_start(\@columns)) {
			if (sum(@pixels) <= $end_y - $start_y) { 
				push @columns, $i; 
			}
		}
		else {
			# need end
			if (sum(@pixels) > $end_y - $start_y) { 
				push @columns, ($i-1)*(-1); 
			}
		}
	}
	push @columns, -$w unless Utils::need_start(\@columns);

	# 2. remove too small lines
	for (my $i = 0; $i < scalar @columns; $i += 2) {
		if ($columns[$i+1] + $columns[$i] > -2) {
			splice @columns, $i, 2; 
			last unless $i < scalar @columns;
			redo;
		}
	}

	# 2.1 join parts of one letter
	for (my $i = 0; $i < scalar(@columns) - 3; $i += 2) {
		if ($columns[$i+1] + $columns[$i+2] <= 2) {
			splice @columns, $i+1, 2;
			last unless $i < scalar(@columns) - 3;
			redo;
		}
	}

	# 3. find accurate y-bounds of each letter 
	# (remove extra white rows)
	my @st = ();
	for (my $i = 0; $i < scalar @columns; $i+=2) {
		# each letter
		my $ww = (-1)* $columns[$i+1] - $columns[$i] + 1;
		for (my $j = $start_y; $j <= $end_y; ++$j) { 
			# each rows in a letter
			my @pixels = $img->GetPixels(
				x      => $columns[$i],
				y      => $j,
				height => 1,
				width  => $ww,
				map    => 'I',
				normalize => 1,
			);
			if (Utils::need_start(\@st)) {
				if (sum(@pixels) <= $ww - 1) {
					push @st, $j;
					last; #we need only one start here
				}
			}
		}
		for (my $j = $end_y; $j >= $start_y; --$j) {
			# each rows in a letter
			my @pixels = $img->GetPixels(
				x      => $columns[$i],
				y      => $j,
				height => 1,
				width  => $ww,
				map    => 'I',
				normalize => 1,
			);
			unless (Utils::need_start(\@st)) {
				if (sum(@pixels) <= $ww - 1) {
					push @st, -$j;
					last; # we need only one end here
				}
			}
		}		
	}

	# 3. get coordinates of letters
	my @letters = ();
	for(my $i = 0; $i < scalar @columns; $i += 2) {
		push @letters, Letter->new(
			x => $columns[$i],
			w => (-1) * $columns[$i+1] - $columns[$i] + 1,
			y => $st[$i],
			h => (-1) * $st[$i+1] - $st[$i] + 1,
		);
	}
	return \@letters;
}


no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
