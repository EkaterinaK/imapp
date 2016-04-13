use Image::Magick;

sub preprocess_img($) {
	my $img = $_[0];
	$img->Normalize();
	$img->UnsharpMask('4x4+6+0');
	$img->Quantize(colorspace=>'gray');
	$img->BlackThreshold("20%");
	$img->WhiteThreshold("20%");
}

my $img = Image::Magick->new();
$img->read("img-test-2-contrast.jpg");
preprocess_img($img);
$img->write("img-test-2-contrast-res.jpg");
$img = undef;
