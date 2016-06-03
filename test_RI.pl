use strict;

use warnings;
use feature qw/say/;
use Data::Dumper;
use ReceiptImage;

my $img = ReceiptImage->new();
$img->Read("img-test-res.jpg");
say "width: " . $img->Get("columns");
say "height: " . $img->Get("rows");


$img->align();
say Dumper($img);
$img->write("after_align.jpg");
$img->_draw_horiz_lines("lines.jpg");
say "DONE";
