use strict;
use warnings;
use Image::Magick;
use Data::Dumper;
use List::Util qw/sum/;
use feature qw/say/;

use Letter;
use Alphabet; 
use Template::Safeway;
use Product;

our $ii = 0;
# use it to decide what we are looking for:
# a start of a text area or an end of it.
# params: arrayref where we store the starts and the ends.
#
sub need_start ($) {
	my $stack = $_[0];
	return 1 if scalar(@$stack) == 0;
	return 1 if $stack->[-1] < 0;
	return 0;
}

# params:
# Image::Magick object - the original image 
# that we want to recognise
#
sub get_lines_coord($) {
	my $img = $_[0];
	my $w = $img->Get('columns');
	my $h = $img->Get('rows');
	my @lines = ();
	
	# !! start with 1 because 0 causes error if 0th line is not empty
	for (my $i = 1; $i < $h; ++$i) {
		#read next line
		my @pixels = $img->GetPixels(
			x     => 0,
			y     => $i,
			map   => 'I',
			normalize => 1,
		);
		
		if (need_start(\@lines)) {
			if (sum(@pixels) <= $w-1) { 
				push @lines, $i; 
			}
		}
		else {
			# need end
			if (sum(@pixels) > $w-1) { 
				push @lines, ($i-1)*(-1); 
			}
		}
	}
	push @lines, -$h unless need_start(\@lines);
	
	# remove too thin lines
	for (my $i = 0; $i < scalar @lines; $i += 2) {
		if ($lines[$i+1] + $lines[$i] > -4) {
			splice @lines, $i, 2; 
			last unless $i < scalar @lines;
			redo;
		}
	}
	return @lines;
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
		
		if (need_start(\@columns)) {
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
	push @columns, -$w unless need_start(\@columns);

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
			if (need_start(\@st)) {
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
			unless (need_start(\@st)) {
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

sub get_resized_pixels_10x10($$) {
	my ($img, $lc) = @_;
	$img->Crop(
		x      => $lc->x(),
		y      => $lc->y(),
		width  => $lc->w(),
		height => $lc->h(),
	);
	$img->Resize(geometry => "10x10!"); # ignore aspect ratio
	$img->BlackThreshold("50%");
	$img->WhiteThreshold("50%");
	$img->write("t/".++$ii. ".jpg");
	my @pixels = $img->GetPixels(
		normalize => 1,
		map => 'I',
		x => 0,
		y => 0,
		width => 10,
		height => 10,
	);
	return \@pixels;
}

sub preprocess_img($) {
	my $img = $_[0];
	$img->Normalize();
	$img->UnsharpMask('4x4+6+0');
	$img->Quantize(colorspace=>'gray');
	$img->BlackThreshold("30%");
	$img->WhiteThreshold("30%");
	return $img;
}

sub _draw_horiz_lines($$$) {
	my ($img3, $coord, $file) = @_;
	my $w = $img3->Get('columns');
	for (my $i = 0; $i < scalar @$coord; ++$i) {
		if ($coord->[$i] > 0) {
			# start red
			$img3->Draw(fill => '#ffff00008080', primitive => 'line', 
				points => "0, $coord->[$i], $w, $coord->[$i]");
		} else {
			# end
			my $a = (-1) * $coord->[$i];
			$img3->Draw(fill =>' #0000ffff8080', primitive => 'line', 
				points => "0, $a, $w, $a");
		}
	}
	$img3->write($file);
}

sub _draw_ver_lines($$$) {
	my ($img, $coord, $start, $end, $file) = @_;
	my $h = $img->Get('rows');
	my $w = $img->Get('columns');
	$img->Draw(fill => 'red', primitive => 'line', 
		points => "$start 0, $start, $w");
	$img->Draw(fill => 'blur', primitive => 'line', 
		points => "$end 0, $end, $w");
	for (my $i = 0; $i < scalar @$coord; ++$i) {
		if ($coord->[$i] > 0) {
			# start
			$img->Draw(fill => 'red', primitive => 'line', 
				points => "$coord->[$i], 0, $coord->[$i], $h");
		} else {
			# end
			my $a = (-1) * $coord->[$i];
			$img->Draw(fill => 'blue', primitive => 'line', 
				points => "$a, 0, $a, $h");
		}

	}
	$img->write($file);
}

sub _draw_borders {
	my ($img, $letters, $file) = @_;
	for my $a (@$letters) {
		my $x0 = $a->{x};
		my $y0 = $a->{y};
		my $x1 = $x0 + $a->{w};
		my $y1 = $y0 + $a->{h};
		#top
		$img->Draw(fill => 'red', primitive => 'line', 
			points => "$x0, $y0, $x1, $y0");
		#bottom
		$img->Draw(fill => 'red', primitive => 'line', 
			points => "$x0, $y1, $x1, $y1");
		#left
		$img->Draw(fill => 'red', primitive => 'line', 
			points => "$x0, $y0, $x0, $y1");
		#right
		$img->Draw(fill => 'red', primitive => 'line', 
			points => "$x1, $y0, $x1, $y1");
	}
	$img->write($file);
}

# $img - copy of original image
# $y0 - first x-coord of bad area
# $y1 - last x-coord of bad area  
sub crop_img($$$) {
	my ($img, $y0, $y1) = @_;
	$img->Crop(x => 0, y => $y0, width => $img->Get('columns'), 
				height => $y1 - $y0 + 1);
	return $img;
}

# $img - copy of original image
# $y0 - first x-coord of bad area
# $y1 - last x-coord of bad area  
sub rotate_img($$$) {
	my ($img, $y0, $y1) = @_;
	$img->Crop(x => 0, y => $y0, width => $img->Get('columns'), height => $y1 - $y0 + 1);
	my @degrees = (0.5, 0.1, 0.2, 0.2, 0.2, -1.4, -0.3, -0.2, -0.2, -0.2);
	#for (my $i = 0; $i < scalar @degrees; ++$i) {
	for my $d (@degrees) {
		say "d = $d";
		$img->Rotate(degrees => $d, background => 'white');
		if (valid_img($img)) {
			say "img is now valid";
			_draw_horiz_lines($img->Clone(), [get_lines_coord($img)], "rotated_$y0.jpg"); 
			last;
		}
	}
	return $img;
}

#------------------------------------

my $img = Image::Magick->new();
$img->Read("img-test-res.jpg"); # good readable black&white picture
#$img->Read("cut.jpg"); # good readable black&white picture
#$img->Read("");
#preprocess_img($img);

my $alphabet = Alphabet->new();

my @lines = get_lines_coord($img);
#_draw_horiz_lines($img->Clone(), \@lines, "lines1.jpg");

my $template = Template::Safeway->new();
$template->width($img->Get('columns'));
$template->line_height(-$lines[1] - $lines[0] + 1); # first line must be OK.

my @valid_img;
my @valid_img_parts = ();
my ($valid_start, $valid_end) = (undef, undef);
# validate lines
for (my $i = 0; $i < scalar @lines; $i += 2) {
	my ($y0, $y1) = ($lines[$i], (-1) * $lines[$i+1]);
	my $valid = $template->is_valid_line($y0, $y1);

	if($valid->[0]) { 
		if (!defined $valid_start) { 
			$valid_start = $lines[$i]; 
			say "valid start $valid_start";	
		}
		if ($i+1 == scalar(@lines) - 1) { 
			say "last part";
			$valid_end = -$lines[$i+1];
			say "valid end $valid_end";
			push @valid_img_parts, crop_img($img->Clone(), 
					$valid_start, $valid_end);
		}
	}
	else {
		# invalid line
		say "INVALID (" . $valid->[1] . ")";
		if (defined $valid_start) {
			$valid_end = -$lines[$i-1];
			say "valid end $valid_end";
			push @valid_img_parts, 
				crop_img($img->Clone(), $valid_start, $valid_end);
			$valid_start = undef;
			$valid_end = undef;
		}
		if ($valid->[1] eq 'big') {
			my $img_new = rotate_img($img->Clone(), $y0, $y1);
			$img_new->write("rotated_$i.jpg");
			say "img written";
			push @valid_img_parts, $img_new;
			#next;
		}
		elsif ($valid->[1] eq 'small') {
			say "skipped small";
		}
		say "------";
	}
}
say Dumper(\@valid_img_parts);
my $img1 = Image::Magick->new(\@valid_img_parts);
for (my $i = 0; $i < scalar @valid_img_parts; ++$i) {
	#$valid_img_parts[$i]->write("p-$i.jpg");
	$img1->[$i] = $valid_img_parts[$i][0];
}
say Dumper($img1);

my $img2 = $img1->Append(stack=> 1);
$img2->write("appended.jpg");

@lines = get_lines_coord($img2);
_draw_horiz_lines($img2->Clone(), \@lines, "appened-lines.jpg"); 


sub valid_img($) {
	my ($img) = @_;
	my @lines = get_lines_coord($img);
	say Dumper(\@lines);
	my $res = 1;
	for (my $i = 0; $i < scalar @lines; $i += 2) {
		my ($y0, $y1) = ($lines[$i], -$lines[$i+1]);
		my $valid = $template->is_valid_line($y0, $y1);
		unless($valid->[0]) { 
			$res = 0; 
			last; 
		}
	}
	return $res;
}
__END__
$img = $img2;

# primary rough recognition
my @preproc_lines = ();
for (my $i = 0; $i < scalar @lines; $i += 2) {
	my ($x0, $x1) = ($lines[$i], (-1) * $lines[$i+1]);
	my $valid;
	if ($i == 0) {
		$template->line_height($x1 - $x0 + 1);
		$valid = [1, undef];
	}
	else {
		$valid = $template->is_valid_line($x0, $x1);
	}

	unless($valid->[0]) {
		# invalid line
		say "INVALID (" . $valid->[1] . ")";
		next;
	}

	my $letters_coord = get_letters_coord(
		$img, 
		$lines[$i], 
		(-1) * $lines[$i+1]
	);
	next if scalar @$letters_coord == 0;

	#_draw_borders($img->Clone(), $letters_coord, "borders2_$i.jpg");

	my $white = sum(map {$_->{w}} @$letters_coord)/(scalar @$letters_coord);
	my $avgh = sum(map {$_->{h}} @$letters_coord)/(scalar @$letters_coord);
	my $str = "";
	for (my $i = 0; $i < scalar @$letters_coord; ++$i) {
	#for my $lc (@$letters_coord) {
		next if $letters_coord->[$i]{h} == 1 || $letters_coord->[$i]{w} == 1;
		my $pixels_10x10 = get_resized_pixels_10x10($img->Clone(), $letters_coord->[$i]);
		my $p10x10 = join '', map {
			if ($_ > 0.9) { $_ = 1 }
			elsif ($_ < 0.1) { $_ = 0 }
		} @$pixels_10x10;
		$letters_coord->[$i]->pix10x10($p10x10);

		#my $letter = ($letters_coord->[$i]{h} < $avgh/7) 
		#			? $alphabet->which_small_sign($p10x10)
		#			: $alphabet->which_letter($p10x10);
		my $letter = $alphabet->which_symbol($p10x10);		
		if ($i > 0) {
			my $d = ($letters_coord->[$i]{x} 
						- ($letters_coord->[$i-1]{x}
						    + $letters_coord->[$i-1]{w})
					)/$white;
			$str .= " " x int(sprintf("%.1f", $d)) if (sprintf("%d", $d) >1.05);
		}
		$str .=  $alphabet->word_to_sign($letter);
	}
	push @preproc_lines, {str => $str, coords => $letters_coord};
	print "$str\n";
}

my @line_types = ();
for my $pl (@preproc_lines) {
	if ($template->is_header($pl)) {
		push @line_types, 'header';
	}
	elsif ($template->is_regprice($pl->{str})) {
		push @line_types, 'regprice';
	}
	elsif ($template->is_creditcard($pl->{str})) {
		push @line_types, 'creditcard';
	}
	elsif ($template->is_weight($pl->{str})) {
		push @line_types, 'weight';
	}
	elsif ($template->is_taxbal($pl->{str})) {
		push @line_types, 'taxbal';
	}
	else {
		push @line_types, '?';
	}
}
say Dumper(\@line_types);
my @a = $template->fill_line_types(\@line_types);
say Dumper(\@a);

my $i = 0;
my $header = '';
my $name = '';
my $price = 0;
my $regprice = 0;
my $cardsavings = 0;
my $creditcard = 0;
my $change = 0;
my $date = 0;
my $product = undef;
my @products = ();

# final processing
while($i < scalar @preproc_lines) {
	my @idx = $template->split_idx($preproc_lines[$i]);
	#say Dumper(\@idx);
	if ($line_types[$i] eq 'header') {
		$header = '';
		for my $s (@{$preproc_lines[$i]->{coords}}) {
			$header .= $alphabet->which_letter($s->{pix10x10});
		}
		# TODO header validation
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
		say "idx_price: " . $idx_price; 
		for (my $j = 0; $j < scalar @idx; ++$j) {
			if ($j == $idx_price) {
				# parse price
				for (my $k = $idx[$j][0]; $k <= $idx[$j][1]; ++$k) {
					my $pix = $preproc_lines[$i]->{coords}[$k]{pix10x10};
					my $d = $alphabet->which_digit_or_point($pix);
					$price .= $alphabet->word_to_sign($d);
				}
			}
			elsif ($j < $idx_price) {
				# parse name
				for (my $k = $idx[$j][0]; $k <= $idx[$j][1]; ++$k) {
					my $pix = $preproc_lines[$i]->{coords}[$k]{pix10x10};
					$name .= $alphabet->which_letter($pix);
				}
				$name .= " ";
			}
			# and don't parse the last letter after price (F/T)
		}
		$product = Product->new(
			name => $name, price => $price, category => $header);
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
			my $d = $alphabet->which_digit_or_point($pix);
			$regprice .= $alphabet->word_to_sign($d);
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
			my $d = $alphabet->which_digit_or_point($pix);
			$cardsavings .= $alphabet->word_to_sign($d);
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
			my $d = $alphabet->which_digit_or_point($pix);
			$creditcard .= $alphabet->word_to_sign($d);
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
			my $d = $alphabet->which_digit_or_point($pix);
			$change .= $alphabet->word_to_sign($d);
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
				my $d .= $alphabet->which_digit_or_punct($pix);
				$date .= $alphabet->word_to_sign($d);
			}
			$date .= " ";
		}
		say "DATE: " . $date;
		++$i;
		next;
	}
	else {
		say "> OTHER";
		++$i; next;
	}
}
say Dumper(\@products);
