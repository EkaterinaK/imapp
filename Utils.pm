package Utils;

use List::Util qw/sum/;
use Data::Dumper;
use feature qw/say/;
use Image::Magick;
use ReceiptImage;

# param is an Image::Magick object
#
sub get_lines_coord($) { 
	my ($img) = @_;
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


# use it to decide what we are looking for:
# a start of a text area or an end of it.
# params: arrayref where we store the starts and the ends.
#
sub need_start ($) {
	my ($stack) = @_;
	return 1 if scalar(@$stack) == 0;
	return 1 if $stack->[-1] < 0;
	return 0;
}

1;
