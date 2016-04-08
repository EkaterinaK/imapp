package Letter;

use Moose;

has 'x' => (is => 'ro', isa => 'Int'); 
has 'y' => (is => 'ro', isa => 'Int'); 
has 'w' => (is => 'ro', isa => 'Int'); 
has 'h' => (is => 'ro', isa => 'Int'); 

no Moose;
__PACKAGE__->meta->make_immutable;
