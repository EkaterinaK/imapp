use strict;
use warnings;
use Image::Magick;
use Data::Dumper;
use List::Util qw/sum/;
use feature qw/say/;

sub need_start ($) {
	my $stack = $_[0];
	return 1 if scalar(@$stack) == 0;
	return 1 if $stack->[-1] < 0;
	return 0;
}

my $img = Image::Magick->new();
$img->Read("cut.jpg"); # good readable black&white picture

my $w = $img->Get('columns');
my $h = $img->Get('rows');

# ----- by rows ----- #

my @stack_r = ();

for (my $i = 0; $i < $h; ++$i) {
	#read next line
	my @pixels = $img->GetPixels(
		x     => 0,
		y     => $i,
		map   => 'I',
		normalize => 1,
	);
	
	if (need_start(\@stack_r)) {
		if (sum(@pixels) <= $w-1) { 
			push @stack_r, $i; 
		}
	}
	else {
		# need end
		if (sum(@pixels) > $w-1) { 
			push @stack_r, ($i-1)*(-1); 
		}
	}
}

push @stack_r, -$h unless need_start(\@stack_r);

print Dumper(\@stack_r[0..3]);

# ----- by columns ----- #

my $start = $stack_r[0];
my $end = (-1) * $stack_r[1];

my @stack_c = ();

for (my $i = 0; $i < $w; ++$i) {
	#read next column part
	my @pixels = $img->GetPixels(
		x     => $i,
		y     => $start,
		height => $end - $start + 1, 
		width => 1,
		map   => 'I',
		normalize => 1,
	);
	
	if (need_start(\@stack_c)) {
		if (sum(@pixels) <= $end - $start) { 
			push @stack_c, $i; 
		}
	}
	else {
		# need end
		if (sum(@pixels) > $end - $start) { 
			push @stack_c, ($i-1)*(-1); 
		}
	}
}
push @stack_c, -$h unless need_start(\@stack_c);

print Dumper(\@stack_c);

# ----- find accurate borders of each letter -----
# ----- (remove extra white rows from each letter in line) ----

my @st = ();
#letters
for (my $i = 0; $i < scalar @stack_c; $i+=2) {
my $ww = (-1)* $stack_c[$i+1] - $stack_c[$i] + 1;
say "width = $ww";
#rows in a letter
for (my $j = $start; $j <= $end; ++$j) { 
	#read line inside a letter square
	my @pixels = $img->GetPixels(
		x      => $stack_c[$i],
		y      => $j,
		height => 1,
		width  => $ww,
		map    => 'I',
		normalize => 1,
	);
	if (need_start(\@st)) {
		if (sum(@pixels) <= $ww - 1) {
			say "sum start: " . sum(@pixels);
			push @st, $j;
		}
	}
	else {
		# need end
		if (sum(@pixels) > $ww - 1) {
			say "sum end: " . sum(@pixels);
			push @st, (-1) * ($j-1);
		}
	}
}		
	push @st, (-1) *  $end unless need_start(\@st);
}
say "accurate borders:";
say Dumper(\@st);



