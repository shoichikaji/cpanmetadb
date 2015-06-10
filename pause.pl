#!/usr/bin/env perl
use strict;
use utf8;
use warnings;
use FindBin;
use DBI;
use HTTP::Tiny;
use JSON::XS ();
use Log::Minimal;
use PerlIO::gzip;
use POSIX qw(strftime);

my $JSON = JSON::XS->new->canonical(1);
my $cache_dir = "cache";
my $details_txt_gz = "$cache_dir/02packages.details.txt.gz";
my $details_txt_gz_url = "http://www.cpan.org/modules/02packages.details.txt.gz";
my $dsn = "dbi:SQLite:dbname=$cache_dir/pause.sqlite3";
my $table_name = "pause";

infof "start http get $details_txt_gz_url";
my $res = HTTP::Tiny->new(timeout => 30)->mirror(
    $details_txt_gz_url => $details_txt_gz,
);

if (!$res->{success}) {
    croakf "failed http get $details_txt_gz_url: $res->{status} $res->{reason}";
} else {
    my $last_modified = strftime("last-modified: %FT%T%z", localtime((stat $details_txt_gz)[9]));
    if ($res->{status} == 304) {
        infof "not modified %s (%s), so exit", $details_txt_gz, $last_modified;
        exit;
    }
    infof "got %.2fMB %s (%s)",
        (-s $details_txt_gz) / (1024**2), $details_txt_gz, $last_modified;
}

my $provides = do {
    open my $fh, "<:gzip", $details_txt_gz or die $!;
    local $_;
    while (<$fh>) {
        last if $_ eq "\n";
    }
    my %provides;
    while (<$fh>) {
        chomp;
        my ($package, $version, $distfile) = split /\s+/, $_, 3;
        push @{$provides{$distfile}}, {
            package => $package,
            version => $version eq "undef" ? undef : $version,
        };
    }
    \%provides;
};
infof "got %d distfiles", scalar(keys %$provides);


my $dbh = DBI->connect($dsn, "", "", { AutoCommit => 1, RaiseError => 1 }) or die;

$dbh->do(<<"...");
CREATE TABLE IF NOT EXISTS `$table_name` (
    `distfile` TEXT NOT NULL PRIMARY KEY,
    `provides` TEXT NOT NULL
)
...

my %exists = do {
    my $rows = $dbh->selectall_arrayref(
        "SELECT `distfile` FROM `$table_name`", {Slice => +{}},
    );
    map { $_->{distfile} => 1 } @$rows;
};

$dbh->begin_work;
my $insert = $dbh->prepare_cached("INSERT INTO `$table_name` VALUES (?, ?)");
my $count = 0;
for my $distfile (sort keys %$provides) {
    next if $exists{$distfile};
    $count++;
    $insert->execute($distfile, $JSON->encode($provides->{$distfile}));
}
$dbh->commit;
infof "finished inserting %d new distfiles", $count;
