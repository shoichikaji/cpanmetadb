# a fork of CPAN Meta DB

https://cpanmetadb-provides.herokuapp.com/

This is a fork of [CPAN Meta DB](http://cpanmetadb.plackperl.org/).

# What is the difference?

`/v1.1/package/Package::Name` returns:

* distfile
* version
* provides (new!)
* requirements (new!)

Example:

https://cpanmetadb-provides.herokuapp.com/v1.1/package/Moo

```
---
distfile: H/HA/HAARG/Moo-2.000001.tar.gz
version: 2.000001
provides:
  -
    package: Method::Generate::Accessor
    version: undef
  -
    package: Method::Generate::BuildAll
    version: undef
  -
    package: Method::Generate::Constructor
    version: undef
  -
    package: Method::Generate::DemolishAll
    version: undef
  -
    package: Method::Inliner
    version: undef
  -
    package: Moo
    version: 2.000001
  -
    package: Moo::_mro
    version: undef
  -
    package: Moo::_strictures
    version: undef
  -
    package: Moo::_Utils
    version: undef
  -
    package: Moo::HandleMoose
    version: undef
  -
    package: Moo::HandleMoose::_TypeMap
    version: undef
  -
    package: Moo::HandleMoose::FakeConstructor
    version: undef
  -
    package: Moo::HandleMoose::FakeMetaClass
    version: undef
  -
    package: Moo::Object
    version: undef
  -
    package: Moo::Role
    version: 2.000001
  -
    package: Moo::sification
    version: undef
  -
    package: oo
    version: undef
  -
    package: Sub::Defer
    version: 2.000001
  -
    package: Sub::Quote
    version: 2.000001
requirements:
  -
    package: ExtUtils::MakeMaker
    version: 0
    phase: configure
    type: requires
  -
    package: Class::Method::Modifiers
    version: 1.1
    phase: runtime
    type: requires
  -
    package: Devel::GlobalDestruction
    version: 0.11
    phase: runtime
    type: requires
  -
    package: Exporter
    version: 5.57
    phase: runtime
    type: requires
  -
    package: Module::Runtime
    version: 0.014
    phase: runtime
    type: requires
  -
    package: Role::Tiny
    version: 2
    phase: runtime
    type: requires
  -
    package: Scalar::Util
    version: 0
    phase: runtime
    type: requires
  -
    package: perl
    version: 5.006
    phase: runtime
    type: requires
```
