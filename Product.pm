package Product;

use Moose;
#use DateTime;

has 'name'     => (is => 'rw', isa => 'Str');
has 'price'    => (is => 'rw', isa => 'Num');
has 'regprice' => (is => 'rw', isa => 'Num', required => 0,);
has 'discount' => (is => 'rw', isa => 'Num', required => 0,);
has 'crv'      => (is => 'rw', isa => 'Num', required => 0,);
has 'category' => (is => 'rw', isa => 'Str');
has 'store'    => (is => 'rw', isa => 'Str', required => 0,);
#has 'date'     => (is => 'rw', isa => 'Int');

sub _tostring() {
	my ($self) = @_;
	return join " ", $self->store, $self->category, $self->name, $self->price, ;
}

no Moose;
__PACKAGE__->meta->make_immutable;
