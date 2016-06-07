package Template::Safeway;

use Moose;
use List::Util qw/all sum sum0/;
use Data::Dumper;
use Time::Local;
use feature qw/say/;

has 'headers' => (
	is => 'ro',
	isa => 'HashRef',
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
	#init_arg => undef,
	
);

#-------- PUBLIC --------

# input:  "6/01/16 14:18"
# output: 1467407880
# meaning in localtime: Fri Jul  1 14:18:00 2016
#
sub str2utime($) {
	my ($self, $str) = @_;
	my $t;
	if($str =~ m# \D* (\d{1,2}) \D+ (\d{1,2}) \D+ (\d{1,2}) \D+ (\d{1,2}) \D+ (\d{1,2})#x) { 
		#print join " ", $1, $2, $3, $4, $5; 
		$t = timelocal(0, $5, $4, $2, $1, 2000 + $3 - 1900); 
	}
	return $t;
}

sub line_types($) {
	my ($self, @preproc_lines) = @_;
	#say Dumper($preproc_lines[1]);
	my @line_types = ();
	for my $pl (@preproc_lines) {
		if ($self->is_header($pl)) {
			push @line_types, 'header';
		}
		elsif ($self->is_regprice($pl->{str})) {
			push @line_types, 'regprice';
		}
		elsif ($self->is_creditcard($pl->{str})) {
			push @line_types, 'creditcard';
		}
		elsif ($self->is_weight($pl->{str})) {
			push @line_types, 'weight';
		}
		elsif ($self->is_taxbal($pl->{str})) {
			push @line_types, 'taxbal';
		}
		else {
			push @line_types, '?';
		}
	}
	say Dumper(\@line_types);
	return @line_types;
}

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
	# 1. check regexp
	my $m = lc($str) =~ /price/i;
	# 2. check distance 1
	my @rp = qw/r e g p r i c e/;
	$str = substr lc($str), 0, 7;
	my @s = split //, $str;
	my $mismatch = 0;
	for (my $i = 0; $i < scalar @s; ++$i) {
		++$mismatch if $s[$i] ne $rp[$i];
	}
	# 3. check distance 2
	$str = substr lc($str), 1, 7;
	my @s1 = split //, $str;
	my $mismatch1 = 0;
	for (my $i = 0; $i < scalar @s1; ++$i) {
		++$mismatch1 if $s1[$i] ne $rp[$i];
	}
	return 1 if ($mismatch <= 3 or $mismatch1 <= 3 or $m);
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
	say "in fill_line_types ". Dumper($line_types);
	for (my $i = 0; $i < scalar @$line_types; ++$i) {
		if ($line_types->[$i] eq 'taxbal' &&
				defined($line_types->[$i+1]) &&
				$line_types->[$i+1] eq 'taxbal') {
			$line_types->[$i] = 'tax';
			next;
		}
		next if $line_types->[$i] ne '?';
		if (defined ($line_types->[$i+1]) && $line_types->[$i+1] eq 'regprice') {
			$line_types->[$i] = 'item';
		}
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

sub split_idx($) {
	my ($self, $line) = @_;
	my @res = ();
	my $i = 0;
	my @words = split /\s+/, $line->{str};
	for my $w (@words) {
		push @res, [ $i, $i + length($w) -1];
		$i += length($w) ;
	}
	return @res;
}

sub get_valid_header($) {
	my ($self, $str) = @_;
	$str = lc($str);
	if (defined $self->headers->{$str}) { 
		say "LOG: header ($str) is perfect";
		return $str; 
	}
	my $res = {w => '', s => 0};
	for my $h (keys %{$self->headers}) {
		say $h;
		my $s = $self->_word_distance($str, $h);
		if ($res->{s} < $s) {
			$res->{s} = $s;
			$res->{w} = $h;
		}
	}
	say "LOG: header ($str) is validated as " . $res->{w} . " (matched " . $res->{s} . ")";
	return $res->{w};
}

sub get_valid_name($) {
	my ($self, $str) = @_;

}

#-------- PRIVATE --------

# $s1 - what we want to validate
# $s2 - whith what we want to compare
sub _word_distance($$) {
	my ($self, $s1, $s2) = @_;
	my @s1 = split //, $s1;
	my @s2 = split //, $s2;
	my $sum = sum0(map {$s2 =~ /$_/} @s1);	
	return $sum;
}

sub _load_headers() {
	return {
		'produce' => 1,
		'grocery' => 1,
		'meat' => 1,
		'floral' => 1,
		'miscellaneous' => 1,
		'refrig/frozen' => 1,
		'gen merchandise' => 1,
		'baked goods' => 1,
	};
}


no Moose;
__PACKAGE__->meta->make_immutable;
