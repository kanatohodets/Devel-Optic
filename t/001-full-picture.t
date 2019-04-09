use strict;
use warnings;

use Test::More;

use Devel::Optic;

subtest 'empty data structures' => sub {
    my $o = Devel::Optic->new;
    my $undef = undef;
    is_deeply($undef, $o->full_picture('$undef'), 'undef');
    my $string = "blorb";
    is_deeply($string, $o->full_picture('$string'), 'simple string');
    my $num = 1234;
    is_deeply($num, $o->full_picture('$num'), 'simple number');
    my @empty_array = ();
    is_deeply(\@empty_array, $o->full_picture('@empty_array'), 'empty array');
    my %empty_hash = ();
    is_deeply(\%empty_hash, $o->full_picture('%empty_hash'), 'empty hash');
    my $empty_arrayref = [];
    is_deeply($empty_arrayref, $o->full_picture('$empty_arrayref'), 'empty arrayref');
    my $empty_hashref = {};
    is_deeply($empty_hashref, $o->full_picture('$empty_hashref'), 'empty hashref');
};

subtest 'valid one level lenses' => sub {
    my $o = Devel::Optic->new;
    my @array = (42);
    is_deeply($array[0], $o->full_picture('@array/0'), 'array index');
    my %hash = (foo => 42);
    is_deeply($hash{foo}, $o->full_picture('%hash/foo'), 'hash key');
    my $arrayref = [42];
    is_deeply($arrayref->[0], $o->full_picture('$arrayref/0'), 'arrayref index');
    my $hashref = {foo => 42};
    is_deeply($hashref->{foo}, $o->full_picture('$hashref/foo'), 'hashref key');
};

subtest 'valid deep lenses, single data type' => sub {
    my $o = Devel::Optic->new;
    my @array = ([[[42]]]);
    is_deeply($array[0]->[0]->[0]->[0], $o->full_picture('@array/0/0/0/0'), 'array nested index');

    my %hash = (foo => { foo => { foo => { foo => 42}}});
    is_deeply($hash{foo}->{foo}->{foo}->{foo}, $o->full_picture('%hash/foo/foo/foo/foo'), 'hash nested key');
    my $arrayref = [[[[42]]]];
    is_deeply($arrayref->[0]->[0]->[0]->[0], $o->full_picture('$arrayref/0/0/0/0'), 'arrayref nested index');
    my $hashref = {foo => { foo => { foo => { foo => 42}}}};
    is_deeply($hashref->{foo}->{foo}->{foo}->{foo}, $o->full_picture('$hashref/foo/foo/foo/foo'), 'hashref nested key');
};

subtest 'valid deep lenses, mixed data types' => sub {
    my $o = Devel::Optic->new;
    my @array = ({ foo => [{ foo => 42}]});
    is_deeply($array[0]->{foo}->[0]->{foo}, $o->full_picture('@array/0/foo/0/foo'), 'array nested mixed type index');

    my %hash = (foo => [{ foo => [42]}]);
    is_deeply($hash{foo}->[0]->{foo}->[0], $o->full_picture('%hash/foo/0/foo/0'), 'hash nested mixed type key');

    my $arrayref = [{ foo => [{ foo => 42}]}];
    is_deeply($arrayref->[0]->{foo}->[0]->{foo}, $o->full_picture('$arrayref/0/foo/0/foo'), 'arrayref nested mixed type index');

    my $hashref = {foo => [{ foo => [42]}]};
    is_deeply($hash{foo}->[0]->{foo}->[0], $o->full_picture('$hashref/foo/0/foo/0'), 'hashref nested mixed type key');
};

done_testing;
