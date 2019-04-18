#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'tests' => 6;
use Devel::Optic;

is_deeply(
    Devel::Optic::_parse_string_spec(q!'foo'!),
    [
        { 'type' => 'key', 'value' => 'foo' },
    ],
    'String: \'foo\'',
);

is_deeply(
    Devel::Optic::_parse_string_spec(q!32!),
    [
        { 'type' => 'index', 'value' => 32 },
    ],
    'String: 32',
);

is_deeply(
    Devel::Optic::_parse_string_spec(q!'foo'/32!),
    [
        { 'type' => 'key',   'value' => 'foo' },
        { 'type' => 'index', 'value' => 32    },
    ],
    'String: \'foo\'/32',
);

is_deeply(
    Devel::Optic::_parse_string_spec(q!'foo'/3/'bar'!),
    [
        { 'type' => 'key',   'value' => 'foo' },
        { 'type' => 'index', 'value' => 3     },
        { 'type' => 'key',   'value' => 'bar' },
    ],
    'String: \'foo\'/3/\'bar\'',
);

is_deeply(
    Devel::Optic::_parse_string_spec(q!'foo'/3/'b\/ar'!),
    [
        { 'type' => 'key',   'value' => 'foo'  },
        { 'type' => 'index', 'value' => 3      },
        { 'type' => 'key',   'value' => 'b/ar' },
    ],
    'String: \'foo\'/3/\b\/ar\'',
);

is_deeply(
    Devel::Optic::_parse_string_spec(q!'fo o'/3/'ba\/r\''/4/5!),
    [
        { 'type' => 'key',   'value' => 'fo o'   },
        { 'type' => 'index', 'value' => 3        },
        { 'type' => 'key',   'value' => 'ba/r\'' },
        { 'type' => 'index', 'value' => 4        },
        { 'type' => 'index', 'value' => 5        },
    ],
    'String: \'fo o\'/3/\'ba\/r\'/4/5',
);
