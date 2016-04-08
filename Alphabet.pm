package Alphabet;

use Moose;
use Image::Magick;

has 'letters' => (
	is => 'ro', 
	isa => 'HashRef',
	init_arg => undef, 
	builder => '_load_letters', 
	#lazy => 1,
);

has 'letters_path' => (
	is => 'ro', 
	isa => 'Str', 
	required => 1, 
	default=>'letters10x10/',
	#reader => 'get_letter
);

#-------- PUBLIC ------------

sub which_letter($$) {
	my ($letters, $v) = @_;
	my $res = {};
	for my $k (keys %$letters) {
		my $dist = distance($letters->{$k}, $v);
		if (!defined $res->{dist} or $res->{dist} < $dist) {
			$res->{dist} = $dist;
			$res->{let} = $k;
		}
	}
	return $res->{let};
}

#-------- PRIVATE  ------------

sub distance($$) {
	my ($a1, $a2) = @_;
	return undef if scalar(@$a1) != scalar(@$a2);
	my $mismatch = 0;
	for (my $i = 0; $i < scalar(@$a1); ++$i) {
		++$mismatch if (abs($a1->[$i] - $a2->[$i]) > 0.1);  
	}
	return $mismatch;
}

sub _load_letters() {
	my @arr = qw/c d e o p r u/;
	my $image;
	my $letters = {};
	for my $i (@arr) {
		$image = Image::Magick->new();
		$image->Read("letters10x10/$i.jpg");
		#$image->Read(letters_path() . "$i.jpg");
		my $w = $image->Get('columns');
		my $h = $image->Get('rows');
		my @pixels = $image->GetPixels(
			x => 0,
			y => 0,
			width => $w,
			height => $h,
			map => 'I',
			normalize => 1,
		);
		$letters->{$i} = \@pixels;
		undef $image;
	}
	return $letters;
}

no Moose;
__PACKAGE__->meta->make_immutable;
