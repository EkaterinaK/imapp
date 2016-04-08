use strict;
use warnings;
use feature qw/say/;
use Image::Magick;
use Data::Dumper;
use List::Util qw/sum/;

my ($image, $x);
$image = Image::Magick->new();
$x = $image->Read("cut.jpg");
#say Dumper($x);
#$image->Grayscale(channel=>"average");
#$image->Contrast(sharpen=>1);
#$image->WhiteThreshold(threshold=>"60%", channel=>'rgb');
#$image->BlackThreshold(threshold=>"60%", channel=>'rgb');
#$x = $image->Write("img6.jpg");
#say Dumper($x);

my @pixels = $image->GetPixels(
	width => 1,
	heigh => 1,
	x     => 0,
	y     => 0,
	map   => 'I',
	normalize => 1,
);
say Dumper(\@pixels);

#say Dumper(\@pixels);
say join " ", @pixels;
my $w = $image->Get('columns');
my $h = $image->Get('rows');
say "HEIGH $h, WIDTH $w";
say sum(@pixels);

my @p = $image->GetPixels(
	x => 391,
	width => 405-391+1,
	y => 62,
	height => 92-62+1,
	map => "I",
	normalize => 1
);
say Dumper(\@p);
for (my $y = 0; $y < 31; ++$y) {
	for (my $x = 0; $x < 15; ++$x) {
		print sprintf("%.2f", $p[$y*15 + $x]) , " ";
	}
	print "\n";
}


__END__

#for (my $i = 101; $i < 301; ++$i) {
#
#	my @pixels = $image->GetPixels(
#		#width => 1,
#		#heigh => 1,
#		x     => 0,
#		y     => $i,
#		map   => 'I',
#		normalize => 1,
#	);
#	say "$i ==> " . sum(@pixels);
#}
for (my $i = 0; $i < $w; ++$i) {
	@pixels = $image->GetPixels(
		x => $i,
		y => 62,
		width => 1,
		height => 96-62,
		map => 'I',
		normalize => 1,
)	;
	#say Dumper(\@pixels);
	say "$i ==> " . sum(@pixels);
}
__END__
for (my $i = 0; $i < 10; ++$i) {
	my @pixels = $image->GetPixels(
		width => 1,
		heigh => 96-62,
		x     => $i,
		y     => 62,
		map   => 'I',
		normalize => 1,
	);
	say "$i ==> " . sum(@pixels);
	say Dumper(\@pixels);
}

#$image->Draw(stroke => 'red', primitives => 'line', points => '0,44,900,55');
#$image->Draw(stroke => 'red', primitives => 'line', points => '0,96,900,107');

#$x = $image->Write("lines.jpg");
