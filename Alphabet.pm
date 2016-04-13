package Alphabet;

use Moose;
use Image::Magick;

use Data::Dumper;
use feature qw/say/;

has 'letters' => (
	is => 'ro', 
	isa => 'HashRef',
	init_arg => undef, 
	builder => '_load_letters', 
	lazy => 1,
);

has 'letters_path' => (
	is => 'ro', 
	isa => 'Str', 
	required => 1, 
	default=>'letters10x10/',
	#reader => 'get_letter
);

has 'signs' => (
	is => 'ro',
	isa => 'HashRef',
	init_arg => undef,
	builder => '_load_signs',
);

has 'small_signs' => (
	is => 'ro',
	isa => 'HashRef',
	init_arg => undef,
	builder => '_small_signs',
);

#-------- PUBLIC ------------

sub which_letter($) {
	my ($self, $v) = @_;
	my $letters = $self->letters;
	#say "===> LETTERS " . Dumper($letters);
	my $res = {};
	for my $k (keys %$letters) {
		my $dist = $self->distance($letters->{$k}, $v);
		#say "++ ", $k, " ", $dist; 
		if (!defined $res->{dist} or $res->{dist} > $dist) {
			$res->{dist} = $dist;
			$res->{let} = $k;
		#	say $res->{let}, " -> ", $res->{dist};
		}
	}
	return $res->{let};
}

sub which_small_sign($) {
	my ($self, $v) = @_;
	my $s = $self->small_signs;
	my $letters = {};
	for my $k (keys %{$self->letters}) {
		if (defined $s->{$k}) {
			$letters->{$k} = $self->letters->{$k};
		}
	}
	#say "===> LETTERS " . Dumper($letters);
	my $res = {};
	for my $k (keys %$letters) {
		my $dist = $self->distance($letters->{$k}, $v);
		#say "++ ", $k, " ", $dist; 
		if (!defined $res->{dist} or $res->{dist} > $dist) {
			$res->{dist} = $dist;
			$res->{let} = $k;
		#	say $res->{let}, " -> ", $res->{dist};
		}
	}
	return $res->{let};
}

sub word_to_sign($) {
	my ($self, $w) = @_;
	return $self->signs->{$w} if defined $self->signs->{$w};
	return $w;
}

#-------- PRIVATE  ------------

sub distance($$) {
	my ($self, $a1, $a2) = @_;
	return undef if scalar(@$a1) != scalar(@$a2);
	my $mismatch = 0;
	for (my $i = 0; $i < scalar(@$a1); ++$i) {
		++$mismatch if (abs($a1->[$i] - $a2->[$i]) > 0.1);  
	}
	return $mismatch;
}

sub _load_letters() {
	#my @arr = qw/c d e o p r u/;
	my $self = $_[0];
	my $path = $self->letters_path;
	opendir(my $dh, $path) or die "Can't open a dir $path ($!)";
	my @arr = map {/^(.+).jpg/} grep {/.jpg/} readdir($dh);
	closedir($dh);
	my $image;
	my $letters = {};
	for my $i (@arr) {
		$image = Image::Magick->new();
		#$image->Read("letters10x10/$i.jpg");
		$image->Read($path . "$i.jpg");
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

sub _load_signs() {
	return {
		_at        => '@',
		_percent   => '%',
		_dollar    => '$',
		_star      => '*',
		_amp       => '&',
		_point     => '.',
		_coma      => ',',
		_colon     => ':',
		_slash     => '/',
		_backslash => "\\",
		_dash      => '-',
		_plus      => '+',

		_e         => 'e',
		_g         => 'g',
		_r         => 'r',
		_i         => 'i',
		_c         => 'c',
		_a         => 'a',
		_d         => 'd',
		_v         => 'v',
		_n         => 'n',
		_s         => 's',
	};
}

sub _small_signs() {
	return {
		_point     => '.',
		_coma      => ',',
		_dash      => '-',
	};
}

no Moose;
__PACKAGE__->meta->make_immutable;
