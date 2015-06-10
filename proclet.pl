#!/usr/bin/env perl
use strict;
use utf8;
use warnings;
use lib "lib";
use Proclet;
use File::RotateLogs;
use Plack::Loader;
use Plack::Util;

my $port = shift || 5000;
my $logger = File::RotateLogs->new(
    logfile => "logs/%Y%m%d.log",
    # linkname => "logs/latest.log",
    rotationtime => 24*60*60,
    maxage => 7*24*60*60,
);

{
    # initial update
    my $pid = open my $fh, "-|";
    if ($pid == 0) {
        open STDERR, ">&STDOUT";
        exec $^X, "pause.pl";
    }
    $logger->print("===> initial update\n");
    while (<$fh>) {
        $logger->print($_);
    }
    close $fh;
    die "failed" if $? != 0;
    $logger->print("===> initial update DONE!\n");
}

my $proclet = Proclet->new(
    logger => sub { $logger->print(@_) },
);

$proclet->service(
    code => sub {
        my $loader = Plack::Loader->load('Starlet',
            port => $port,
            host => '0.0.0.0',
            max_workers => 4,
        );
        $loader->run(Plack::Util::load_psgi("app.psgi"));
    },
    tag => "web",
);

$proclet->service(
    code => sub {
        exec $^X, "ping.pl";
    },
    tag => "ping",
);

$proclet->service(
    code => sub {
        exec $^X, "pause.pl";
    },
    every => "*/15 * * * *",
    tag => "pause",
);

$proclet->run;
