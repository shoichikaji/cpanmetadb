use strict;
use warnings;
use 5.10.1;
use CPANMetaDB;
use Plack::App::File;
use Plack::App::Directory;
use DBI;
use DBIx::Simple;
use DBD::SQLite;
use JSON::XS 'decode_json';
use Encode 'encode_utf8';
use Plack::Builder;

my $root = Plack::App::File->new(file => "public/index.html")->to_app;
my $logs = Plack::App::Directory->new(root => "logs")->to_app;
my $cache_dir = "cache";
my $dsn = "dbi:SQLite:dbname=$cache_dir/pause.sqlite3";

sub write_yaml {
    my ($distfile, $provides) = @_;
    my $yaml = <<"...";
---
distfile: $distfile
provides:
...
    for my $provide (@$provides) {
        $yaml .= <<"...";
  -
    package: @{[ $provide->{package} ]}
    version: @{[ $provide->{version} // 'undef' ]}
...
    }
    $yaml;
}

get '/' => [$root];

get '/v1.0/provides/*' => sub {
    my ($req, $param) = @_;
    my $distfile = $param->{splat}[0];
    my $db = DBIx::Simple->connect($dsn);
    my $db_res = $db->query("SELECT provides FROM pause WHERE distfile=? LIMIT 1", $distfile);
    my $result = $db_res->hash;
    $db->disconnect;

    unless ($result) {
        return Plack::Response->new(404,  ["Content-Type" => "text/plain"], "Not found\n");
    }

    my $provides = decode_json $result->{provides};

    my $res = Plack::Response->new(200);
    $res->content_type('text/yaml');
    my $yaml = write_yaml($distfile, $provides);
    $res->content_length(length $yaml);
    $res->body($yaml);
    $res;
};

builder {
    mount "/logs" => $logs;
    mount "/" => app;
}
