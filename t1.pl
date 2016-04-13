use Alphabet;
use Image::Magick;

my $a = Alphabet->new();
my $img = Image::Magick->new();
$img->read("t/4.jpg");

my @p = $img->GetPixels(x=>0, y=>0, width=> 10, height=>10, 
	map => 'I', normalize => 1);

my $let = $a->which_letter(\@p);
print $let , "\n";
