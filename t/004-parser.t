#!/usr/bin/perl
use strict;
use warnings;
use Test2::V0;
use Devel::Optic::Parser;

subtest 'valid lexes' => sub {
    my $test = '$foo';
    is(Devel::Optic::Parser::lex($test), [$test], "Simple scalar: $test");
    $test = '%foo';
    is(Devel::Optic::Parser::lex($test), [$test], "Simple hash: $test");
    $test = '@foo';
    is(Devel::Optic::Parser::lex($test), [$test], "Simple array: $test");

    $test = '%foo->{bar}';
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { bar } )], "Simple hash access: $test");

    $test = '%foo->{b-ar}';
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { b-ar } )], "Key with dash: $test");

    $test = '%foo->{b\->ar}';
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { b->ar } )], "Key with escaped arrow: $test");

    $test = q|%foo->{'bar'}|;
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { 'bar' } )], "Quoted string key: $test");

    $test = q|%foo->{'b->ar'}|;
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { 'b->ar' } )], "Quoted arrow: $test");

    $test = q|%foo->{'b}ar'}|;
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { 'b}ar' } )], "Brace in string: $test");

    $test = q|%foo->{b\}ar}|;
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { b}ar } )], "Escaped brace: $test");

    $test = q|%foo->{'b\}ar'}|;
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { 'b}ar' } )], "Escaped brace in string: $test");

    $test = q|%foo->{}|;
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { } )], "Empty key: $test");

    $test = q|%foo->{ba\'r}|;
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { ba'r } )], "Escaped quote: $test");

    $test = q|%foo->{bar}->[-2]->{foo}->{blorg}->[22]|;
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { bar } -> [ -2 ] -> { foo } -> { blorg } -> [ 22 ])], "Deep access: $test");

    $test = q|%foo->{$bar}|;
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { $bar } )], "Nested vars: $test");

    $test = q|%foo->{$bar->[-1]}|;
    is(Devel::Optic::Parser::lex($test), [qw( %foo -> { $bar -> [ -1 ] } )], "Nested vars with nested access: $test");
};

subtest 'invalid lexes' => sub {
};

subtest 'valid parses' => sub {

};

subtest 'invalid parses' => sub {

};

done_testing;
