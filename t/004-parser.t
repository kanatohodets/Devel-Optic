#!/usr/bin/perl
use strict;
use warnings;
use Test2::V0;
use Devel::Optic::Parser qw(
    :constants
    lex
    parse
);

# note: not all valid lexes are valid parses (tokens might be invalid for a range of reasons)
subtest 'valid lexes' => sub {
    for my $test (qw($foo @foo %foo)) {
        is([ lex($test) ], [$test], "Symbol '$test'");
    }

    my $test = '%foo->{bar}';
    is([ lex($test) ], [qw( %foo -> { bar } )], "Simple hash access: $test");

    $test = '%foo->{b-ar}';
    is([ lex($test) ], [qw( %foo -> { b-ar } )], "Key with dash: $test");

    $test = '%foo->{b\->ar}';
    is([ lex($test) ], [qw( %foo -> { b->ar } )], "Key with escaped arrow: $test");

    $test = q|%foo->{'bar'}|;
    is([ lex($test) ], [qw( %foo -> { 'bar' } )], "Quoted string key: $test");

    $test = q|%foo->{'b->ar'}|;
    is([ lex($test) ], [qw( %foo -> { 'b->ar' } )], "Quoted arrow: $test");

    $test = q|%foo->{'b}ar'}|;
    is([ lex($test) ], [qw( %foo -> { 'b}ar' } )], "Brace in string: $test");

    $test = q|%foo->{b\}ar}|;
    is([ lex($test) ], [qw( %foo -> { b}ar } )], "Escaped brace: $test");

    $test = q|%foo->{'b\}ar'}|;
    is([ lex($test) ], [qw( %foo -> { 'b}ar' } )], "Escaped brace in string: $test");

    $test = q|%foo->{}|;
    is([ lex($test) ], [qw( %foo -> { } )], "Empty key: $test");

    $test = q|%foo->{ba\'r}|;
    is([ lex($test) ], [qw( %foo -> { ba'r } )], "Escaped quote: $test");

    $test = q|%foo->{bar}->[-2]->{foo}->{blorg}->[22]|;
    is([ lex($test) ], [qw( %foo -> { bar } -> [ -2 ] -> { foo } -> { blorg } -> [ 22 ])], "Deep access: $test");

    $test = q|%foo->{$bar}|;
    is([ lex($test) ], [qw( %foo -> { $bar } )], "Nested vars: $test");

    $test = q|%foo->{$bar->[-1]}|;
    is([ lex($test) ], [qw( %foo -> { $bar -> [ -1 ] } )], "Nested vars with nested access: $test");
};

subtest valid_parses => sub {
    for my $test (qw($foo @foo %foo)) {
        is(parse(lex($test)), [SYMBOL, $test], "Symbol '$test'");
    }

    my $test = q|%foo->{'bar'}|;
    is(parse(lex($test)),
        [OP_ACCESS, [
            [SYMBOL, '%foo'],
            [OP_HASHKEY,
                [STRING, 'bar']]]],
        "$test"
    );

    $test = q|@foo->[3]|;
    is(parse(lex($test)),
        [OP_ACCESS, [
            [SYMBOL, '@foo'],
            [OP_ARRAYINDEX,
                [NUMBER, 3]]]],
        "$test"
    );

    $test = q|$foo->[0]|;
    is(parse(lex($test)),
        [OP_ACCESS, [
            [SYMBOL, '$foo'],
            [OP_ARRAYINDEX,
                [NUMBER, 0]]]],
        "$test"
    );

    $test = q|$foo->{0}|;
    is(parse(lex($test)),
        [OP_ACCESS, [
            [SYMBOL, '$foo'],
            [OP_HASHKEY,
                [NUMBER, 0]]]],
        "$test"
    );

    $test = q|%foo->{$bar}|;
    is(parse(lex($test)),
        [OP_ACCESS, [
            [SYMBOL, '%foo'],
            [OP_HASHKEY,
                [SYMBOL, '$bar']]]],
        "$test"
    );

    $test = q|%foo->{'bar'}->[-2]->{'baz'}|;
    is(parse(lex($test)),
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
    is(parse(lex($test)),
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

done_testing;
