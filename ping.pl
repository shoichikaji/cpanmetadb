#!/usr/bin/env perl
use 5.20.0;
use utf8;
use warnings;
use IO::Socket::SSL;
use HTTP::Tiny;

my $self = "https://cpanmetadb-provides.herokuapp.com/ping";
my $sleep = 13 * 60;
my $ua = HTTP::Tiny->new;

while (1) {
    $ua->get($self);
    sleep $sleep;
}
