package Receipt;

use Moose;

has 'store'     => (is => 'rw', isa => 'Str');
has 'total'     => (is => 'rw', isa => 'Num');
has 'tax'       => (is => 'rw', isa => 'Num', default => 0,);
has 'datetime'  => (is => 'rw', isa => 'Int');

sub _tostring() {
	my ($self) = @_;
	return join " ", $self->store, $self->category, $self->name, $self->price, ;
}

no Moose;
__PACKAGE__->meta->make_immutable;
