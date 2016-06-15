package ReceiptImage;

use Moose;
use MooseX::InsideOut;
#use MooseX::NonMoose;
use List::Util qw/sum/;
use Data::Dumper;
use feature qw/say/;

extends 'Image::Magick';

has 'line_height' => (is => 'rw', isa => 'Int', init_arg => undef,
	builder => '_set_line_height', lazy => 1);

# ======== PUBLIC ========

sub preprocess() {
	my ($self) = @_;
	$self->Normalize();
	$self->UnsharpMask('4x4+6+0');
	$self->Quantize(colorspace=>'gray');
	$self->BlackThreshold("30%");
	$self->WhiteThreshold("30%");
	#return $self;
}

# выравнивание каждой строки так, чтобы она стала минимальной высоты
sub align2() {
	#TODO 
	my ($self) = @_;
	my @lines = get_lines_coord($self);
	my @valid_img_parts = ();
	for (my $i = 0; $i < scalar @lines; $i =+ 2) {
		my ($y0, $y1) = ($lines[$i], -$lines[$i+1]);
		my $img_new = rotate_img2($self->Clone(), $y0, $y1);
		$img_new->BlackThreshold('50%');
		$img_new->WhiteThreshold('50%');
		$img_new->write("rotated_$i.jpg");
		say "\timg written";
		push @valid_img_parts, $img_new;

	}
}

# !! changes object in place
sub align() {
	my ($self) = @_; 
	my @lines = get_lines_coord($self);
	$self->line_height(-$lines[1] - $lines[0] + 1); #first line must be perfect 

	my @valid_img_parts = ();
	my ($valid_start, $valid_end) = (undef, undef);
	
	# validate lines
	for (my $i = 0; $i < scalar @lines; $i += 2) {
		my ($y0, $y1) = ($lines[$i], -$lines[$i+1]);
		my $valid = $self->is_valid_line($y0, $y1);

		say "LINE $y0, $y1 - $valid";

		if($valid eq 'ok') { 
			if (!defined $valid_start) { 
				$valid_start = $lines[$i]; 
			}
			if ($i+1 == scalar(@lines) - 1) { 
				$valid_end = -$lines[$i+1];
				push @valid_img_parts, crop_img($self->Clone(), 
						$valid_start, $valid_end);
			}
		}
		else {
			# invalid line
			#say "INVALID (" . $valid . ")";
			if (defined $valid_start) {
				#---- add blank image --------------
				my $w = $self->Get("columns");
				my $h = $y0 - (-$lines[$i-1]);
				my $img_blank = ReceiptImage->new();
				$img_blank->Set(size=>"$w"."x"."$h");
				$img_blank->ReadImage('canvas:white');
				push @valid_img_parts, $img_blank;
				say "(blank img before REGULAR added)";
				#---- add regular part-------
				$valid_end = -$lines[$i-1];
				#say "valid end $valid_end";
				push @valid_img_parts, 
					crop_img($self->Clone(), $valid_start, $valid_end);
				$valid_start = undef;
				$valid_end = undef;
			}
			if ($valid eq 'big') {
				#---- add blank image --------------
				my $w = $self->Get("columns");
				my $h = $y0 - (-$lines[$i-1]);
				my $img_blank = ReceiptImage->new();
				$img_blank->Set(size=>"$w"."x"."$h");
				$img_blank->ReadImage('canvas:white');
				push @valid_img_parts, $img_blank;
				say "(blank img before big added)";
				#---- construct new rotated image----
				my $img_new = rotate_img($self->Clone(), $y0, $y1);
				$img_new->BlackThreshold('50%');
				$img_new->WhiteThreshold('50%');
				$img_new->write("rotated_$i.jpg");
				say "\timg written";
				push @valid_img_parts, $img_new;
				#next;
			}
			elsif ($valid eq 'small') { 
				say "(skipped)";
				my $w = $self->Get("columns");
				my $h = $y1 - (-$lines[$i-1]);
				my $img_blank = ReceiptImage->new();
				$img_blank->Set(size=>"$w"."x"."$h");
				$img_blank->ReadImage('canvas:white');
				push @valid_img_parts, $img_blank;
				say "(blank img instead of small added)";
			}
			say "------";
		}
	}

	# construct a new image from parts and assign it to $self
	my $img1 = ReceiptImage->new();
	for (my $i = 0; $i < scalar @valid_img_parts; ++$i) {
		$img1->[$i] = $valid_img_parts[$i][0];
	}
	
	my $appended = $img1->Append(stack => 1);
	$appended->Set(page=> "0x0+0+0");
	$appended->write("appended.jpg");
    @$self = @$appended;

}

# ======== OVERRIDE ========

sub Clone() {
	my ($self) = @_;
	my $res = $self->SUPER::Clone();
	$res->line_height($self->line_height);
	return $res;
}

# ======== PRIVATE ========

# use it to decide what we are looking for:
# a start of a text area or an end of it.
# params: arrayref where we store the starts and the ends.
#
sub need_start ($) {
	my ($stack) = @_;
	return 1 if scalar(@$stack) == 0;
	return 1 if $stack->[-1] < 0;
	return 0;
}

# is the line valid according to the perfect line_height?
# return values: 'ok', 'big', 'small'
sub is_valid_line($$) {
	my ($self, $x0, $x1) = @_;
	my $h = $x1 - $x0 + 1;
	return 'big' if ($h >= 2 * $self->line_height);
	return 'small' if ($h < 0.5 * $self->line_height);
	return 'ok';
}


sub get_lines_coord($) { 
	my ($img) = @_;
	my $w = $img->Get('columns');
	my $h = $img->Get('rows');
	my @lines = ();
	
	# !! start with 1 because 0 causes error if 0th line is not empty
	for (my $i = 1; $i < $h; ++$i) {
		#read next line
		my @pixels = $img->GetPixels(
			x     => 0,
			y     => $i,
			map   => 'I',
			normalize => 1,
		);
		
		if (need_start(\@lines)) {
			if (sum(@pixels) <= $w-1) { 
				push @lines, $i; 
			}
		}
		else {
			# need end
			if (sum(@pixels) > $w-1) { 
				push @lines, ($i-1)*(-1); 
			}
		}
	}
	push @lines, -$h unless need_start(\@lines);
	
	# remove too thin lines
	for (my $i = 0; $i < scalar @lines; $i += 2) {
		if ($lines[$i+1] + $lines[$i] > -4) {
			splice @lines, $i, 2; 
			last unless $i < scalar @lines;
			redo;
		}
	}
	return @lines;
}

# $img - copy of original image
# $y0 - first x-coord of bad area
# $y1 - last x-coord of bad area  
#
sub rotate_img($$$) {
	my ($img, $y0, $y1) = @_;
	print "\trotating... ";
	$img->Crop(	x => 0, y => $y0, 
		width => $img->Get('columns'), 
		height => $y1 - $y0 + 1);
	#my @degrees = (0.5, 0.1, 0.2, 0.2, 0.2, -1.4, -0.3, -0.2, -0.2, -0.2);
	my @degrees = (0.5, 0.1, 0.2, 0.2, 0.2,0.2, 0.2,0.2,0.2,0.2,0.2,0.2, -2.8, -0.3, -0.2, -0.2, -0.2, -0.2, -0.2, -0.2, -0.2, -0.2, -0.2, -0.2);
	#my @degrees = (0.5, 0.1, 0.2, 0.2, 0.2, -1.4, -0.1, -0.1, -0.1, -0.1, -0.1, -0.2, -0.2);
	for my $d (@degrees) {
		print "$d ";
		$img->Rotate(degrees => $d, background => 'white');
		if (valid_img($img)) {
			say "\n\trotation done. img is now valid.";
			#_draw_horiz_lines($img->Clone(), [get_lines_coord($img)], 
			#	"rotated_$y0.jpg"); 
			last;
		}
	}
	return $img;
}

# $img - copy of original image
# $y0 - first x-coord of bad area
# $y1 - last x-coord of bad area  
sub crop_img($$$) {
	my ($img, $y0, $y1) = @_;
	$img->Crop(x => 0, y => $y0, width => $img->Get('columns'), 
				height => $y1 - $y0 + 1);
	return $img;
}

sub valid_img($) {
	my ($img) = @_;
	my @lines = get_lines_coord($img);
	#say Dumper(\@lines);
	my $res = 1;
	for (my $i = 0; $i < scalar @lines; $i += 2) {
		my ($y0, $y1) = ($lines[$i], -$lines[$i+1]);
		my $valid = $img->is_valid_line($y0, $y1);
		unless($valid eq 'ok') { 
			$res = 0; 
			last; 
		}
	}
	return $res;
}

sub _draw_horiz_lines($) {
	my ($self, $file) = @_;
	my $img = $self->Clone();
	my $w = $img->Get('columns');
	my @coord = get_lines_coord($img);
	for (my $i = 0; $i < scalar @coord; ++$i) {
		if ($coord[$i] > 0) {
			# start red
			$img->Draw(fill => '#ffff00008080', primitive => 'line', 
				points => "0, $coord[$i], $w, $coord[$i]");
		} else {
			# end
			my $a = (-1) * $coord[$i];
			$img->Draw(fill =>' #0000ffff8080', primitive => 'line', 
				points => "0, $a, $w, $a");
		}
	}
	$img->write($file);
}

sub _set_line_height() {
	my ($self) = @_;
	my @lines = get_lines_coord($self);
	$self->line_height(-$lines[1] - $lines[0] + 1); #first line must be perfect 
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

__END__
$self->align();
my $letter_info = $self->letters_info();

