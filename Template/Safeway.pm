package Template::Safeway;

use Moose;
use List::Util qw/all/;
use Data::Dumper;
use feature qw/say/;

has 'headers' => (
	is => 'ro',
	isa => 'ArrayRef',
	init_arg => undef,
	builder => '_load_headers',
);

has 'line_height' => (
	is => 'rw',
	isa => 'Int',
	init_arg => undef,
);

has 'width' => (
	is => 'rw',
	isa => 'Int',
	init_arg => undef,
);

#-------- PUBLIC --------

sub is_valid_line($$) {
	my ($self, $x0, $x1) = @_;
	my $h = $x1 - $x0 + 1;
	return [0, 'big'] if ($h >= 2 * $self->line_height);
	return [0, 'small'] if ($h < 0.5 * $self->line_height);
	return [1, undef];
}

sub is_header($) {
	my ($self, $line) = @_;
	my $loffset = $line->{coords}[0]{x};
	my $roffset = $self->width - ($line->{coords}[-1]{x} + $line->{coords}[-1]{w});
	if ($loffset > $self->width * (1/6) && 
		$roffset > $self->width * (1/6) &&
		abs($loffset - $roffset) < 0.5 * $loffset) {
			return 1;
	}
	return 0; 
}

sub is_regprice($) {
	my ($self, $str) = @_;
	my @rp = qw/r e g p r i c e/;
	$str = substr lc($str), 0, 7;
	my @s = split //, $str;
	my $mismatch = 0;
	for (my $i = 0; $i < scalar @s; ++$i) {
		++$mismatch if $s[$i] ne $rp[$i];
	}
	return 1 if $mismatch <= 2;
	return 0;
}

sub is_weight($) {
	my ($self, $str) = @_;
	return 1 if $str =~ /@\s+\$/; # @ $9.99 / lb
	return 0;
}

sub is_creditcard($) {
	my ($self, $str) = @_;
	return 1 if $str =~ /xxxxx/i;
	return 0;
}

sub is_taxbal($) {
	my ($self, $str) = @_;
	return 1 if $str =~ /\*{4,}/i;
	return 0;
}

sub fill_line_types($) {
	my ($self, $line_types) = @_;
	for (my $i = 0; $i < scalar @$line_types; ++$i) {
		next if $line_types->[$i] ne '?';
		if (defined ($line_types->[$i+1]) && $line_types->[$i+1] eq 'regprice') {$line_types->[$i] = 'item'}
		elsif ($line_types->[$i-1] eq 'regprice') {$line_types->[$i] = 'cardsavings'}
		elsif ($line_types->[$i-1] eq 'weight') {$line_types->[$i] = 'item'}
		elsif ($line_types->[$i-1] eq 'creditcard') {$line_types->[$i] = 'change'}
		elsif ($line_types->[$i-1] eq 'change') {$line_types->[$i] = 'date'}
		elsif ($line_types->[$i-1] eq 'taxbal') {$line_types->[$i] = 'cash'}
		elsif ($line_types->[$i-1] eq 'cash') {$line_types->[$i] = 'change'}
		else {$line_types->[$i] = 'item'}
	}
	return @$line_types;
}

#-------- PRIVATE --------

sub _load_headers() {
	return [
		'produce',
		'grocery',
		'meat',
		'floral',
		'miscellaneous',
		'refrig/frozen',
		'gen merchandise',
		'baked goods',
	];
}


no Moose;
__PACKAGE__->meta->make_immutable;
