use strict;
use warnings;
use YAML qw/LoadFile/;
use Product;
use feature qw/say/;
use Data::Dumper;
use Storage;
use DBI;
use DBD::SQLite;

my $yaml = LoadFile("receipts.yml");
say Dumper($yaml);

my $dbh = DBI->connect("dbi:SQLite:dbname=dbfile", "", "");
$dbh->{AutoCommit} = 1;

my $storage = Storage->new({dbh => $dbh});
$storage->add_receipt($yaml);
say Dumper($storage->get_all_receipts());

__END__
my $yaml = LoadFile("products.json");
say Dumper($yaml);

my $dbh = DBI->connect("dbi:SQLite:dbname=dbfile", "", "");
$dbh->{AutoCommit} = 1;

my $storage = Storage->new({dbh => $dbh});
$storage->add_products($yaml, 4);
say Dumper($storage->get_all_products());

