use strict;
use warnings;
use DBI;
use DBD::SQLite;
use Data::Dumper;
use feature qw/say/;

my $dbh = DBI->connect("dbi:SQLite:dbname=dbfile", "", "");
$dbh->{AutoCommit} = 1;
say Dumper($dbh);


#my $a = $dbh->selectall_arrayref('SELECT * FROM receipts;');
#say Dumper($a);
#my $b = $dbh->selectall_arrayref('SELECT * FROM products;');
#say Dumper($b);
#
#my $stm = $dbh->prepare('INSERT INTO receipts VALUES (?,?,?,?,?);');
#$stm->execute(1, "Safeway", 27.15, 0.33, 1464790680);
#$a = $dbh->selectall_arrayref('SELECT * FROM receipts;');
#say Dumper($a);

my $r = {store => "Safeway", total => 27.15, tax => 0.33, datetime => 1464790680};
my $last_id = add_receipt($r);
say "last inserted id: $last_id";

my $p = {name => lc('STRBKS ALL NATURAL'), group_name => lc('GROCERY'), price => 6.99, regprice => 10.99, discount => 4.00};
add_products([$p], $last_id);

my $a = $dbh->selectall_arrayref('SELECT * FROM receipts;');
say Dumper($a);

my $b = $dbh->selectall_arrayref('SELECT * FROM products;');
say Dumper($b);

#package Storage;

sub add_receipt {
	my ($r) = @_;
	my $stm = $dbh->prepare('INSERT INTO receipts VALUES (?,?,?,?,?);');
	my $res = $stm->execute(undef, $r->{store}, $r->{total}, $r->{tax}, $r->{datetime});
	say "res = $res";
	return $dbh->last_insert_id(undef, undef, undef, undef);
}

sub add_products($) {
	my ($products, $receipt_id) = @_;
	my $stm = $dbh->prepare('INSERT INTO products VALUES (?,?,?,?,?,?,?,?);');
	for my $p (@$products) {
		my $res = $stm->execute(undef,$p->{name}, $p->{group_name}, $p->{price}, $p->{regprice}, $p->{discount}, $p->{quantity}, $receipt_id);
		print "res = $res";
	}
}

__END__
my $stm = $dbh->prepare('CREATE TABLE  receipts (
	id         INTEGER   PRIMARY KEY AUTOINCREMENT, 
	store      TEXT,
	total      REAL,
	tax        REAL,
	datetime   INTEGER
	);'
);
$stm->execute();

$stm = $dbh->prepare(
'CREATE TABLE  products (
	id         INTEGER   PRIMARY KEY, 
	name       TEXT, 
	group_name TEXT,
	price      REAL,
	regprice   REAL,
	discount   REAL,
	quantity   INTEGER,
	receipt_id INTEGER,
	FOREIGN KEY(receipt_id) REFERENCES receipts(id)
	);'
);

#say Dumper($stm);
$stm->execute();
my @tables = $dbh->tables();
say Dumper(\@tables);

