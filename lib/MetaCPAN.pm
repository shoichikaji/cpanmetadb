package MetaCPAN;
use strict;
use warnings;
use utf8;
use HTTP::Tiny;
use IO::Socket::SSL;
use JSON::XS ();
use CHI;

our $URL = "https://api.metacpan.org/release";

sub new {
    my ($class, $dir) = @_;
    my $cache = CHI->new(
        driver => 'File',
        root_dir => $dir,
    );
    my $ua = HTTP::Tiny->new(
        agent => "contact: https://github.com/shoichikaji/cpanmetadb-provides",
        timeout => 10,
    );
    bless { cache => $cache, ua => $ua }, $class;
}

sub cache { shift->{cache} }
sub ua { shift->{ua} }

sub fetch_requirements {
    my ($self, $distfile) = @_;
    my $hit = 1;
    my $requirements = $self->cache->compute($distfile, undef, sub {
        undef $hit;
        $self->_fetch_requirements($distfile);
    });
    ($requirements, $hit);
}

sub _fetch_requirements {
    my ($self, $distfile) = @_;
    $distfile =~ s{^./../}{};
    $distfile =~ s{\.(?:tar\.gz|zip|tgz|tar\.bz2)$}{};
    my $res = $self->ua->get("$URL/$distfile");
    return unless $res->{success};
    if (my $json = eval { JSON::XS::decode_json($res->{content}) }) {
        my $requirements = $json->{dependency} or return;

        for my $requirement (@$requirements) {
            my $relationship = delete $requirement->{relationship}; # requires/suggests...
            my $module = delete $requirement->{module};
            my $version_numified = delete $requirement->{version_numified};
            $requirement->{type} = $relationship;
            $requirement->{package} = $module;
        }

        my %priority = (configure => 5, build => 4, runtime => 3);
        return [
            sort { $priority{$b->{phase}} <=> $priority{$a->{phase}} }
            sort { $a->{package} cmp $b->{package} }
            grep { $priority{$_->{phase}} && $_->{type} eq "requires" }
            @$requirements
        ]
    }
    return;
}

1;
