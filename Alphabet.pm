package Alphabet;

use Moose;
use Image::Magick;
use List::Util qw/sum/;

use Data::Dumper;
use feature qw/say/;
use experimental qw/bitwise/;

has 'letters' => (is => 'ro', isa => 'HashRef',	init_arg => undef, 
	builder => '_load_letters', lazy => 1, );

has 'digits' => (is => 'ro', isa => 'HashRef', init_arg => undef,
	builder => '_load_digits', lazy => 1, );

has 'punct' => (is => 'ro', isa => 'HashRef', init_arg => undef,
	builder => '_load_punct', lazy => 1, );

has 'all_symbols' => (is => 'ro', isa => 'HashRef', init_arg => undef,
	builder => '_get_all_symbols', lazy => 1, );

has 'letters_path' => (is => 'ro', isa => 'Str', required => 1, 
	default=>'letters10x10/', );

has 'digits_path' => (is => 'ro', isa => 'Str', required => 1, 
	default=>'digits10x10/', );

has 'punct_path' => (is => 'ro', isa => 'Str', required => 1, 
	default=>'punct10x10/', );

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

# which_symbol('0101111000011110');
sub which_symbol($) {
	my ($self, $v) = @_;
	my $letters = $self->all_symbols;
	my $res = {};
	for my $k (keys %$letters) {
		my $dist = $self->distance($k, $v);
		if (!defined $res->{dist} or $res->{dist} > $dist) {
			$res->{dist} = $dist;
			$res->{let} = $letters->{$k};
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
	my $res = {};
	for my $k (keys %$letters) {
		my $dist = $self->distance($k, $v);
		if (!defined $res->{dist} or $res->{dist} > $dist) {
			$res->{dist} = $dist;
			$res->{let} = $k;
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
	my @a1 = split //, $a1;
	my @a2 = split //, $a2; 
	return undef if scalar(@a1) != scalar(@a2);
	my $mismatch = 0;
	for (my $i = 0; $i < scalar @a1; ++$i) {
		++$mismatch if (abs($a1[$i] - $a2[$i]) > 0.1);  
	}
	return $mismatch;
}

# distance('0101', '0100') --> 1
# distance('0101', '0110') --> 2
sub distance2($$) {
	my ($self, $a1, $a2) = @_;
	return undef if length($a1) != length($a2);
	#my $vect = ($a1 | $a2) - ($a1 & $a2);
	#my $vect = ($a1 ^. $a2);
	#my $mismatch = sum split //, $vect;
	#my @a = split //, $vect;
	#say "VECT " . $vect;
	#return $mismatch;
	return 2;
}

sub _load_letters() {
	my ($self) = @_;
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
		my @pixels = map { if ($_ > 0.9) { $_ = 1} elsif ($_ < 0.1) { $_ = 0} } $image->GetPixels(
			x => 0,
			y => 0,
			width => $w,
			height => $h,
			map => 'I',
			normalize => 1,
		);
		my $p = join "", @pixels;
		if(length($i) > 1) {
			$i =~ s/_//g;
			$i =~ /(.)/ and $i = $1;
		}
		$letters->{$p} = $i;
		undef $image;
	}
	return $letters;
}

sub _load_digits() {
	my ($self) = @_;
	my $path = $self->digits_path;
	opendir(my $dh, $path) or die "Can't open a dir $path ($!)";
	my @arr = map {/^(.+).jpg/} grep {/.jpg/} readdir($dh);
	closedir($dh);
	my $image;
	my $digits = {};
	for my $i (@arr) {
		$image = Image::Magick->new();
		$image->Read($path . "$i.jpg");
		my $w = $image->Get('columns');
		my $h = $image->Get('rows');
		my @pixels = map { if ($_ > 0.9) { $_ = 1} elsif ($_ < 0.1) { $_ = 0} } $image->GetPixels(
			x => 0,
			y => 0,
			width => $w,
			height => $h,
			map => 'I',
			normalize => 1,
		);
		my $p = join "", @pixels;
		if(length($i) > 1) {
			$i =~ s/_//g;
			$i =~ /(.)/ and $i = $1;
		}
		$digits->{$p} = $i;
		undef $image;
	}
	return $digits;
}

sub _load_punct() {
	my ($self) = @_;
	my $path = $self->punct_path;
	opendir(my $dh, $path) or die "Can't open a dir $path ($!)";
	my @arr = map {/^(.+).jpg/} grep {/.jpg/} readdir($dh);
	closedir($dh);
	my $image;
	my $punct = {};
	for my $i (@arr) {
		$image = Image::Magick->new();
		$image->Read($path . "$i.jpg");
		my $w = $image->Get('columns');
		my $h = $image->Get('rows');
		my @pixels = map { if ($_ > 0.9) { $_ = 1} elsif ($_ < 0.1) { $_ = 0} } $image->GetPixels(
			x => 0,
			y => 0,
			width => $w,
			height => $h,
			map => 'I',
			normalize => 1,
		);
		my $p = join "", @pixels;
		$punct->{$p} = $i;
		undef $image;
	}
	return $punct;
}

sub _get_all_symbols() {
	my ($self) = @_;
	return { %{$self->letters}, %{$self->digits}, %{$self->punct}};
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
		
		_1         => '1',
		_2         => '2',
		_3         => '3',
		_4         => '4',
		_5         => '5',
		_6         => '6',
		_7         => '7',
		_8         => '8',
		_9         => '9',

		_GG        => 'G',
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
