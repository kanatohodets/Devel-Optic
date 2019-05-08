package Devel::Optic::Interpreter;
use strict;
use warnings;

use Devel::Optic::Constants qw(:all);
use Scalar::Util qw(looks_like_number);
use Ref::Util qw(is_arrayref is_refref is_scalarref is_ref);
use PadWalker qw(peek_my);

sub run {
    my ($uplevel, $ast) = @_;
    my $scope = peek_my($uplevel);
    my ($type, $payload) = @$ast;
    if ($type eq OP_ACCESS) {
        return access($scope, $payload);
    }

    if ($type eq SYMBOL) {
        return symbol($scope, $payload);
    }

    die "must start with access or symbol";
}

sub access {
    my ($scope, $children) = @_;

    my ($left, $right) = @$children;

    my ($l_arg, $r_arg);
    my ($l_type, $l_val) = @$left;
    my ($r_type, $r_val) = @$right;

    if ($l_type eq SYMBOL) {
        $l_arg = symbol($scope, $l_val);
    }

    if ($l_type eq OP_ACCESS) {
        $l_arg = access($scope, $l_val);
    }

    if ($r_type eq OP_ACCESS) {
        die "not OK";
    }

    if ($r_type eq OP_HASHKEY) {
        return hashkey($scope, $l_arg, $r_val);
    }

    if ($r_type eq OP_ARRAYINDEX) {
        return arrayindex($scope, $l_arg, $r_val);
    }
}

sub arrayindex {
    my ($scope, $left, $child) = @_;
    my ($type, $value) = @$child;
    if ($type eq STRING) {
        die "can't index array with a string";
    }

    my $index;
    if ($type eq NUMBER) {
        $index = $value;
    }

    if ($type eq SYMBOL) {
        my $resolved = symbol($scope, $value);
        if (!looks_like_number($resolved)) {
            die "array indexes have to be numbers";
        }
        $index = $resolved;
    }

    if ($type eq OP_ACCESS) {
        my $resolved = access($scope, $value);
        if (!looks_like_number($resolved)) {
            die "array indexes have to be numbers";
        }
        $index = $resolved;
    }

    if (defined $index) {
        my $len = scalar @$left;
        # negative indexes need checking too
        if ($len <= $index || ($index < 0 && ((-1 * $index) > $len))) {
            die "does not exist: array is only $len elements long, but you want position $index";
        }

        return $left->[$index];
    }

    die "wtf array index";
}

sub hashkey {
    my ($scope, $left, $child) = @_;
    my ($type, $value) = @$child;

    my $key;
    if ($type eq STRING || $type eq NUMBER) {
        $key = $value;
    }

    if ($type eq SYMBOL) {
        my $resolved = symbol($scope, $value);
        if (is_ref($resolved)) {
            die "can't use a ref to key into a hash";
        }

        $key = $resolved;
    }

    if ($type eq OP_ACCESS) {
        my $resolved = access($scope, $value);
        if (is_ref($resolved)) {
            die "can't use a ref to key into a hash";
        }

        $key = $resolved;
    }

    if (defined $key) {
        if (!exists $left->{$key}) {
            die "no such key '$key' in hash";
        }

        return $left->{$key};
    }

    die "wtf hash key";
}

sub symbol {
    my ($scope, $name) = @_;

    die "no symbol $name" if !exists $scope->{$name};
    my $val = $scope->{$name};
    if (is_refref($val) || is_scalarref($val)) {
        return $$val;
    }

    return $val;
}

1;
