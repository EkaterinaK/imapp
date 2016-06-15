package ImageCorrector;

use Moose;
use Image::Magick;
use ReceiptImage;

has 'files' => (is => 'ro', isa => 'ArrayRef');

sub make {
	my ($self) = @_;
	my @images = ();
	for my $f (@{$self->files}) {
		my $img = ReceiptImage->new();
		$img->Read($f);
		$img->preprocess();
		$img->align();
		push @images, $img;
	}
	my $img_fin = scalar @images == 1 ? $images[0] : accemble_multi_img(\@images);
	return $img_fin;
}

# makes one image from an array of images
sub accemble_multi_img($) {
	my ($arr) = @_;

	# construct a new image from parts and assign it to $self
	my $img = ReceiptImage->new();
	for (my $i = 0; $i < scalar @$arr; ++$i) {
		$img->[$i] = $arr->[$i][0];
	}
	
	my $appended = $img->Append(stack => 1);
	$appended->Set(page=> "0x0+0+0");
    return $appended;
}

no Moose;
__PACKAGE__->meta->make_immutable;
