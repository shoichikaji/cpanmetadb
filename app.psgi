use strict;
use warnings;
use 5.10.1;
use CPANMetaDB;
use Plack::App::File;
use Plack::App::Directory;
use Encode 'encode_utf8';
use Plack::Builder;
use POSIX qw(strftime);
use Time::Duration ();

my $start = time;
my $root = Plack::App::File->new(file => "public/index.html")->to_app;
my $logs = Plack::App::Directory->new(root => "logs")->to_app;
my $dbname = "cache/pause.sqlite3";
my $dsn = "dbi:SQLite:dbname=$dbname";

{
    package MyDB;
    use JSON::XS 'decode_json';
    use parent 'DBIx::Simple';
    sub get_distfile {
        my ($db, $package) = @_;
        my $db_res = $db->query("SELECT distfile,version FROM packages_table WHERE package=? LIMIT 1", $package);
        my $result = $db_res->hash
            or return;
        ($result->{distfile}, $result->{version});
    }
    sub get_provides {
        my ($db, $distfile) = @_;
        my $db_res = $db->query("SELECT provides FROM provides_table WHERE distfile=? LIMIT 1", $distfile);
        my $result = $db_res->hash
            or return;
        decode_json $result->{provides};
    }
}

sub write_yaml {
    my ($distfile, %opt) = @_;
    my $yaml = <<"...";
---
distfile: $distfile
...
    if (my $version = $opt{version}) {
        $yaml .= <<"...";
version: @{[$version || 'undef' ]}
...
    }
    if (my $provides = $opt{provides}) {
        $yaml .= <<"...";
provides:
...
        for my $provide (@$provides) {
            $yaml .= <<"...";
  -
    package: @{[ $provide->{package} ]}
    version: @{[ $provide->{version} // 'undef' ]}
...
        }
    }
    $yaml;
}

sub res_404 {
    Plack::Response->new(404,  ["Content-Type" => "text/plain"], "Not found\n");
}
sub res_yaml {
    my $yaml = shift;
    my $res = Plack::Response->new(200);
    $res->content_type('text/yaml');
    $res->content_length(length $yaml);
    $res->body($yaml);
    $res;
}

get '/' => [$root];

get '/ping' => sub {
    my $res = Plack::Response->new(200);
    my $body = sprintf "uptime %s, since %s\n",
        Time::Duration::duration(time - $start), strftime("%F %T %Z(%z)", localtime($start));
    my $mtime = (stat $dbname)[9];
    $body .= sprintf "%s, last modified %s ago\n", $dbname,
        Time::Duration::duration(time - $mtime);
    $res->content_type("text/plain");
    $res->content_length(length $body);
    $res->body($body);
    $res;
};

get '/v1.1/package/:package' => sub {
    my ($req, $param) = @_;
    my $package = $param->{package};

    my $db = MyDB->connect($dsn);
    my ($distfile, $version, $provides);
    ($distfile, $version) = $db->get_distfile($package);
    $provides = $db->get_provides($distfile) if $distfile;
    $db->disconnect;

    return res_404 unless $distfile;

    res_yaml write_yaml($distfile, version => $version, provides => $provides);
};

get '/v1.0/provides/*' => sub {
    my ($req, $param) = @_;
    my $distfile = $param->{splat}[0];
    my $db = MyDB->connect($dsn);
    my $provides = $db->get_provides($distfile);
    $db->disconnect;

    return res_404 unless $distfile;

    res_yaml write_yaml($distfile, provides => $provides);
};

builder {
    mount "/logs" => $logs;
    mount "/" => app;
}
