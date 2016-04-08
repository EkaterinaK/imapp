use strict;
use warnings;
use feature qw/say/;
use Image::Magick;
use Data::Dumper;
use List::Util qw/sum/;

my ($image, $x);
$image = Image::Magick->new();
$image->Read("cut.jpg");
say Dumper($image);


sub resize_img ($$) {
	my ($coords, $img) = @_;
	$img->Crop(
		x      => $coords->{x},
		y      => $coords->{y},
		width  => $coords->{width},
		height => $coords->{height},
	);
	$img->Resize(geometry => "10x10!"); # ignore aspect ratio
	$img->BlackThreshold("50%");
	$img->WhiteThreshold("50%");
	my @pixels = $img->GetPixels(
		normalize => 1,
		map => 'I',
		x => 0,
		y => 0,
		width => 10,
		height => 10,
	);
	say "w " . $img->Get("columns");
	say "h " . $img->Get("rows");
	return \@pixels;
}

my $a = resize_img({x=>391, y=>67, width => 15, height => 24}, $image->Clone());

say scalar @$a;
#say Dumper($a);
say "width " . $image->Get("columns");
say "height " . $image->Get("rows");

