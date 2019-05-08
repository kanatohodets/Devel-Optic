#!/usr/bin/perl
use strict;
use warnings;
use Test2::V0;

use Devel::Optic::Constants qw(:all);
use Devel::Optic::Parser::Perlish;

# note: not all valid lexes are valid parses (tokens might be invalid for a range of reasons)
subtest 'valid lexes' => sub {
    my $p = Devel::Optic::Parser::Perlish->new;
    for my $test (qw($foo @foo %foo)) {
        is([ $p->lex($test) ], [$test], "Symbol '$test'");
    }

    my $test = '%foo->{bar}';
    is([ $p->lex($test) ], [qw( %foo -> { bar } )], "Simple hash access: $test");

    $test = '%foo->{b-ar}';
    is([ $p->lex($test) ], [qw( %foo -> { b-ar } )], "Key with dash: $test");

    $test = '%foo->{b\->ar}';
    is([ $p->lex($test) ], [qw( %foo -> { b->ar } )], "Key with escaped arrow: $test");

    $test = q|%foo->{'bar'}|;
    is([ $p->lex($test) ], [qw( %foo -> { 'bar' } )], "Quoted string key: $test");

    $test = q|%foo->{'b->ar'}|;
    is([ $p->lex($test) ], [qw( %foo -> { 'b->ar' } )], "Quoted arrow: $test");

    $test = q|%foo->{'b}ar'}|;
    is([ $p->lex($test) ], [qw( %foo -> { 'b}ar' } )], "Brace in string: $test");

    $test = q|%foo->{b\}ar}|;
    is([ $p->lex($test) ], [qw( %foo -> { b}ar } )], "Escaped brace: $test");

    $test = q|%foo->{'b\}ar'}|;
    is([ $p->lex($test) ], [qw( %foo -> { 'b}ar' } )], "Escaped brace in string: $test");

    $test = q|%foo->{}|;
    is([ $p->lex($test) ], [qw( %foo -> { } )], "Empty key: $test");

    $test = q|%foo->{ba\'r}|;
    is([ $p->lex($test) ], [qw( %foo -> { ba'r } )], "Escaped quote: $test");

    $test = q|%foo->{bar}->[-2]->{foo}->{blorg}->[22]|;
    is([ $p->lex($test) ], [qw( %foo -> { bar } -> [ -2 ] -> { foo } -> { blorg } -> [ 22 ])], "Deep access: $test");

    $test = q|%foo->{$bar}|;
    is([ $p->lex($test) ], [qw( %foo -> { $bar } )], "Nested vars: $test");

    $test = q|%foo->{$bar->[-1]}|;
    is([ $p->lex($test) ], [qw( %foo -> { $bar -> [ -1 ] } )], "Nested vars with nested access: $test");
};

subtest invalid_lexes => sub {
    my $p = Devel::Optic::Parser::Perlish->new;
    like(
        dies { $p->lex("") },
        qr/invalid syntax: empty spec/,
        "empty spec exception"
    );

    like(
        dies { $p->lex("foobar") },
        qr/invalid syntax: spec must start with a Perl symbol/,
        "missing sigil at start"
    );

    like(
        dies { $p->lex(q|$foobar->{'foo}|) },
        qr/invalid syntax: unclosed string/,
        "unclosed string"
    );
};

subtest valid_parses => sub {
    my $p = Devel::Optic::Parser::Perlish->new;
    for my $test (qw($foo @foo %foo)) {
        is($p->parse($test), [SYMBOL, $test], "Symbol '$test'");
    }

    my $test = q|%foo->{'bar'}|;
    is($p->parse($test),
        [OP_ACCESS, [
            [SYMBOL, '%foo'],
            [OP_HASHKEY,
                [STRING, 'bar']]]],
        "$test"
    );

    $test = q|@foo->[3]|;
    is($p->parse($test),
        [OP_ACCESS, [
            [SYMBOL, '@foo'],
            [OP_ARRAYINDEX,
                [NUMBER, 3]]]],
        "$test"
    );

    $test = q|$foo->[0]|;
    is($p->parse($test),
        [OP_ACCESS, [
            [SYMBOL, '$foo'],
            [OP_ARRAYINDEX,
                [NUMBER, 0]]]],
        "$test"
    );

    $test = q|$foo->{0}|;
    is($p->parse($test),
        [OP_ACCESS, [
            [SYMBOL, '$foo'],
            [OP_HASHKEY,
                [NUMBER, 0]]]],
        "$test"
    );

    $test = q|%foo->{$bar}|;
    is($p->parse($test),
        [OP_ACCESS, [
            [SYMBOL, '%foo'],
            [OP_HASHKEY,
                [SYMBOL, '$bar']]]],
        "$test"
    );

    $test = q|%foo->{'bar'}->[-2]->{'baz'}|;
    is($p->parse($test),
        [OP_ACCESS, [
            [OP_ACCESS, [
                [OP_ACCESS, [
                    [SYMBOL, '%foo'],
                    [OP_HASHKEY,
                        [ STRING, 'bar']]]],
                [OP_ARRAYINDEX,
                    [ NUMBER, -2]]]],
            [OP_HASHKEY,
                [STRING, 'baz']]]],
        "$test"
    );

    $test = q|%foo->{$bar->[0]}|;
    is($p->parse($test),
        [OP_ACCESS, [
            [SYMBOL, '%foo'],
            [OP_HASHKEY,
                [OP_ACCESS, [
                    [SYMBOL, '$bar'],
                    [OP_ARRAYINDEX,
                        [NUMBER, 0]]]]]]],
        "$test"
    );
};

subtest invalid_parses => sub {
    my $p = Devel::Optic::Parser::Perlish->new;
    like(
        dies { $p->parse(q|$fo#obar|) },
        qr/invalid symbol: "\$fo#obar". symbols must start with a Perl sigil \(.+\) and contain only word characters/,
        "invalid symbol"
    );

    like(
        dies { $p->parse(q|$foobar->|) },
        qr/invalid syntax: '->' needs something on the right hand side/,
        "dangling access"
    );

    like(
        dies { $p->parse(q|$foobar->#|) },
        qr/invalid syntax: -> expects either hash key "\{'foo'\}" or array index "\[0\]" on the right hand side/,
        "access weird right hand side"
    );

    like(
        dies { $p->parse(q|$foobar->{bar}|) },
        qr/unrecognized token 'bar'\. hash key strings must be quoted with single quotes/,
        "unquoted hash key"
    );

    like(
        dies { $p->parse(q|$foobar->{'baz'|) },
        qr/invalid syntax: unclosed hash key/,
        "dangling brace"
    );

    like(
        dies { $p->parse(q|$foobar->[0|) },
        qr/invalid syntax: unclosed array index/,
        "dangling bracket"
    );
};

done_testing;
