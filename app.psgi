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
use MetaCPAN;

my $start = time;
my $root = Plack::App::File->new(file => "public/index.html")->to_app;
my $logs = Plack::App::Directory->new(root => "logs")->to_app;
my $dbname = "cache/pause.sqlite3";
my $dsn = "dbi:SQLite:dbname=$dbname";
my $metacpan = MetaCPAN->new("cache/chi");

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
    if (my $requirements = $opt{requirements}) {
        $yaml .= <<"...";
requirements:
...
        for my $requirement (@$requirements) {
            my $version = $requirement->{version} || 0;
            $version = 0 if $version eq 'undef';
            $yaml .= <<"...";
  -
    package: @{[ $requirement->{package} ]}
    version: @{[ $version ]}
    phase: @{[ $requirement->{phase} ]}
    type: @{[ $requirement->{type} ]}
...
        }
    }
    $yaml;
}

sub res_404 {
    Plack::Response->new(404,  ["Content-Type" => "text/plain"], "Not found\n");
}
sub res_yaml {
    my %opt = @_;
    my $body = $opt{body};
    my $res = Plack::Response->new(200);
    $res->content_type('text/yaml');
    $res->content_length(length $body);
    $res->body($body);
    if (my $header = $opt{header}) {
        while (my ($k, $v) = each %$header) {
            $res->header($k => $v);
        }
    }
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

    my $yaml = write_yaml(
        $distfile,
        version => $version, provides => $provides,
    );

    res_yaml body => $yaml;
};

get '/v1.2/package/:package' => sub {
    my ($req, $param) = @_;
    my $package = $param->{package};

    my $db = MyDB->connect($dsn);
    my ($distfile, $version, $provides);
    ($distfile, $version) = $db->get_distfile($package);
    $provides = $db->get_provides($distfile) if $distfile;
    $db->disconnect;

    return res_404 unless $distfile;

    my ($requirements, $cache_hit)
        = $metacpan->fetch_requirements($distfile);
    return res_404 unless $requirements;

    my $yaml = write_yaml(
        $distfile,
        version => $version, provides => $provides, requirements => $requirements,
    );

    res_yaml body => $yaml, header => {'X-Cache' => $cache_hit ? 1 : 0};
};

builder {
    mount "/logs" => $logs;
    mount "/" => app;
}
