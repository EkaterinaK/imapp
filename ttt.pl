use strict;
use warnings;
use Image::Magick;
use Data::Dumper;
use List::Util qw/sum/;
use feature qw/say/;

use Letter;
use Alphabet; 
use Template::Safeway;

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

	# 3. find accurate y-bounds of each letter 
	# (remove extra white rows)
	my @st = ();
	#say "===> num of columns " . scalar @columns;
	#say Dumper(\@columns) if scalar @columns == 2;
	for (my $i = 0; $i < scalar @columns; $i+=2) {
		#each letter
		my $ww = (-1)* $columns[$i+1] - $columns[$i] + 1;
		#say "==> ww $ww";
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
				}
			}
			else {
				# need end
				if (sum(@pixels) > $ww - 1) {
					push @st, (-1) * ($j-1);
				}
			}
		}		
		push @st, (-1) *  $end_y unless need_start(\@st);
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
