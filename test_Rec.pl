use strict;
use warnings;
use feature qw/say/;
use Data::Dumper;
use ReceiptImage;
use Alphabet;
use Template::Safeway;
use Product;
use Recognizer;
use YAML qw/Dump/; 

my $img = ReceiptImage->new();
$img->Read("after_align.jpg");
say "width: " . $img->Get("columns");
say "height: " . $img->Get("rows");

my $recognizer = Recognizer->new({
	img => $img,
	alphabet => Alphabet->new(),
	template => Template::Safeway->new({width => $img->Get('columns')})
});
my $rec = $recognizer->recognize();
say Dumper($rec->{products});
say Dumper($rec->{receipt});


my $yaml = Dump($rec->{receipt});
open(my $fh, ">", "receipts.yml") or die "Can't open file receipts.yml";
print $fh $yaml;
close($fh);
