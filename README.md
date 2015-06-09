# a fork of CPAN Meta DB

https://cpanmetadb-provides.herokuapp.com/

This is a fork of [CPAN Meta DB](http://cpanmetadb.plackperl.org/).

# What is the difference?

Returns the providing packages

Example:

https://cpanmetadb-provides.herokuapp.com/v1.0/provides/M/MI/MIYAGAWA/Plack-1.0036.tar.gz

```
---
distfile: M/MI/MIYAGAWA/Plack-1.0036.tar.gz
provides:
  -
    package: HTTP::Message::PSGI
    version: undef
  -
    package: HTTP::Server::PSGI
    version: undef
  -
    package: Plack
    version: 1.0036
  -
    package: Plack::App::Cascade
    version: undef
```



