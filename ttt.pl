use strict;
use warnings;
use Image::Magick;
use Data::Dumper;
use List::Util qw/sum/;
use feature qw/say/;

use Letter;
use Alphabet; 
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
	
	for (my $i = 0; $i < $h; ++$i) {
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
	for (my $i = 0; $i < $w; ++$i) {
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

	# 2. find accurate y-bounds of each letter 
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

#------------------------------------

my $alphabet = Alphabet->new();
my $img = Image::Magick->new();
$img->Read("img-test-res.jpg"); # good readable black&white picture
#$img->Read("");
#preprocess_img($img);


my @lines = get_lines_coord($img);
print Dumper(\@lines);
my $img2 = $img->Clone();
my $www = $img2->Get('columns');
for (my $i = 0; $i < scalar @lines; $i += 2) {
	if ($lines[$i+1] + $lines[$i] > -4) {
		splice @lines, $i, 2; 
		last unless $i < scalar @lines;
		redo;
	}
	$img2->Draw(fill => 'red', primitive => 'line', 
		points => "0, $lines[$i], $www, $lines[$i]");
	$img2->Draw(fill => 'blue', primitive => 'line', 
		points => "0,". (-1)*$lines[$i+1] .", $www," . (-1)*$lines[$i+1]);
}
print Dumper(\@lines);
$img2->write("img-test-2-res-lines.jpg");
$img2 = undef;

for (my $i = 0; $i < scalar @lines; $i += 2) {
	my $letters_coord = get_letters_coord(
		$img, 
		$lines[$i], 
		(-1) * $lines[$i+1]
	);
	say "==> line $i " . $lines[$i];
	my $white = sum(map {$_->{w}} @$letters_coord)/((scalar @$letters_coord));
	#say "===> White $white";
	my $avgh = sum(map {$_->{h}} @$letters_coord)/((scalar @$letters_coord));
	for (my $i = 0; $i < scalar @$letters_coord; ++$i) {
	#for my $lc (@$letters_coord) {
		next if $letters_coord->[$i]{h} == 1 || $letters_coord->[$i]{w} == 1;
		my $pixels_10x10 = get_resized_pixels_10x10($img->Clone(), $letters_coord->[$i]);

		my $letter = ($letters_coord->[$i]{h} < $avgh/7) 
					? $alphabet->which_small_sign($pixels_10x10)
					: $alphabet->which_letter($pixels_10x10);
		# add whitespaces between words
		if ($i > 0) {
			my $d = ($letters_coord->[$i]{x} 
						- ($letters_coord->[$i-1]{x}
						    + $letters_coord->[$i-1]{w})
					)/$white;
			#print "==> d $d";
			print " " x int(sprintf("%.1f", $d)) if (sprintf("%d", $d) >1.05);
		}
		print $alphabet->word_to_sign($letter);
	}
	print "\n";
}
