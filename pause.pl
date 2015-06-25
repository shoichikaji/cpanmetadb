#!/usr/bin/env perl
use strict;
use utf8;
use warnings;
use FindBin;
use DBI;
use HTTP::Tiny;
use JSON::XS ();
use PerlIO::gzip;
use POSIX qw(strftime);
sub _log {
    my $format = shift;
    sprintf "[%s] $format\n", strftime("%FT%T%z", localtime), @_;
}
sub infof  { warn _log(@_) }
sub croakf { die  _log(@_) }

my $cache_dir = "$FindBin::Bin/cache";
my $details_txt_gz = "$cache_dir/02packages.details.txt.gz";
my $details_txt_gz_url = "http://cpan.metacpan.org/modules/02packages.details.txt.gz";
my $dbname = "$cache_dir/pause.sqlite3";
my $current_dbname = "$dbname." . time;
my $dsn = "dbi:SQLite:dbname=$current_dbname";

infof "start http get $details_txt_gz_url";
my $res = HTTP::Tiny->new(
    agent => "contact: https://github.com/shoichikaji/cpanmetadb-provides",
    timeout => 30,
)->mirror(
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

my ($packages, $provides) = do {
    open my $fh, "<:gzip", $details_txt_gz or die $!;
    local $_;
    while (<$fh>) {
        last if $_ eq "\n";
    }
    my (%packages, %provides);
    while (<$fh>) {
        chomp;
        my ($package, $version, $distfile) = split /\s+/, $_, 3;
        $packages{$package} = { version => $version, distfile => $distfile };
        push @{$provides{$distfile}}, {
            package => $package,
            version => $version eq "undef" ? undef : $version,
        };
    }
    (\%packages, \%provides);
};
infof "got %d packages, %d distfiles", scalar(keys %$packages), scalar(keys %$provides);

my $dbh = DBI->connect($dsn, "", "", { AutoCommit => 1, RaiseError => 1 }) or die;

$dbh->do(<<"...");
CREATE TABLE IF NOT EXISTS `packages_table` (
    `package` TEXT NOT NULL PRIMARY KEY,
    `version` TEXT NOT NULL,
    `distfile` TEXT NOT NULL
)
...
$dbh->do(<<"...");
CREATE TABLE IF NOT EXISTS `provides_table` (
    `distfile` TEXT NOT NULL PRIMARY KEY,
    `provides` TEXT NOT NULL
);
...

$dbh->begin_work;
my $insert_packages = $dbh->prepare_cached("INSERT INTO `packages_table` VALUES (?, ?, ?)");
for my $package (sort keys %$packages) {
    $insert_packages->execute($package, @{$packages->{$package}}{qw(version distfile)});
}
my $insert_provides = $dbh->prepare_cached("INSERT INTO `provides_table` VALUES (?, ?)");
my $JSON = JSON::XS->new->canonical(1);
for my $distfile (sort keys %$provides) {
    $insert_provides->execute($distfile, $JSON->encode($provides->{$distfile}));
}
$dbh->commit;
infof "finished to inserting to db";

infof "symlink $current_dbname to $dbname";
my $tmp_dbname = "$dbname.tmp";
unlink $tmp_dbname if -e $tmp_dbname || -l $tmp_dbname;
symlink $current_dbname, $tmp_dbname
    or croakf "failed to symlink $current_dbname, $tmp_dbname: $!";
rename $tmp_dbname, $dbname
    or croakf "failed to rename $tmp_dbname, $dbname: $!";

my @old = grep { $_ ne $current_dbname } glob "$dbname.*";
for my $old (@old) {
    infof "unlink old $old";
    unlink $old or croakf "failed to unlink old $old: $!";
}
