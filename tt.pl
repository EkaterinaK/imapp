use strict;
use warnings;
use Image::Magick;
use JSON qw/to_json from_json/;
use Data::Dumper;

sub distance($$) {
	my ($a1, $a2) = @_;
	return undef if scalar(@$a1) != scalar(@$a2);
	my $mismatch = 0;
	for (my $i = 0; $i < scalar(@$a1); ++$i) {
		++$mismatch if (abs($a1->[$i] - $a2->[$i]) > 0.1);  
	}
	return $mismatch;
}

sub load_letters {
	my @arr = qw/c d e o p r u/;
	print Dumper(\@arr);
	my ($image, $x);
	my $letters = {};
	for my $i (@arr) {
		$image = Image::Magick->new();
		$x = $image->Read("letters10x10/$i.jpg");
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

sub find_letter($$) {
	my ($letters, $v) = @_;
	my $distances = {};
	for my $k (keys %$letters) {
		my $dist = distance($letters->{$k}, $v);
		$distances->{$k} = $dist;
	}
	my @sorted_k = sort { $distances->{$a} <=> $distances->{$b} } keys %$distances;
	return $sorted_k[0];
}

# ========================== #

my $d = load_letters();

my $pp2 = Image::Magick->new();
$pp2->Read("ppp5.jpg");
my @pp2_pixels = $pp2->GetPixels(
	x => 0,
	y => 0,
	width => $pp2->Get('columns'),
	height => $pp2->Get('rows'),
	map => 'I',
	normalize => 1,
);

for my $k (keys %$d) {
	my $dist = distance($d->{$k}, \@pp2_pixels);
	print "$k ==> $dist\n";
}

my $res = find_letter($d, \@pp2_pixels);
print "result ==> $res\n\n";

__END__
open (my $fh, ">", "letters.json") or die "Can't open file: $!";
print $fh to_json($d);
close $fh;


__END__
my $d = distance([1,0,1,1], [0,1,1,1]);
print $d . "\n";
