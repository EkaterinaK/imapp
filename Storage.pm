package Storage;

use Moose;
use DBI;
use DBD::SQLite;
use Product;
use Receipt;
use feature qw/say/;

has 'dbh' => (is => 'rw', isa => 'Object');

sub add_receipt {
	my ($self, $r) = @_;
	my $stm = $self->dbh->prepare('INSERT INTO receipts VALUES (?,?,?,?,?);');
	my $res = $stm->execute(undef, $r->store, $r->total, $r->tax, $r->datetime);
	#say "res = $res";
	return $self->dbh->last_insert_id(undef, undef, undef, undef);
}

sub add_products {
	my ($self, $products, $receipt_id) = @_;
	my $stm = $self->dbh->prepare('INSERT INTO products VALUES (?,?,?,?,?,?,?,?);');
	for my $p (@$products) {
		my $res = $stm->execute(undef, $p->name, $p->category, $p->price,
			$p->regprice, $p->discount, 1, $receipt_id);
	}
	say "===> add_products() done";
}

sub get_all_products {
	my ($self) = @_;
	my $res = $self->dbh->selectall_arrayref('SELECT * FROM products;');
	return $res;
}

sub get_all_receipts {
	my ($self) = @_;
	my $res = $self->dbh->selectall_arrayref('SELECT * FROM receipts;');
	return $res;
}


no Moose;
__PACKAGE__->meta->make_immutable();
