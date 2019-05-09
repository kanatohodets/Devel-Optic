package Devel::Optic::Lens::Perlish::Interpreter;
use strict;
use warnings;
use Exporter qw(import);
our @EXPORT_OK = qw(run);

use Carp qw(croak);
our @CARP_NOT = qw(Devel::Optic::Lens::Perlish Devel::Optic);

use Devel::Optic::Lens::Perlish::Constants qw(:all);

use Scalar::Util qw(looks_like_number);
use Ref::Util qw(is_arrayref is_refref is_scalarref is_ref);

sub run {
    my ($scope, $ast) = @_;
    my ($type, $payload) = @$ast;
    if ($type eq OP_ACCESS) {
        return _access($scope, $payload);
    }

    if ($type eq SYMBOL) {
        return _symbol($scope, $payload);
    }

    croak "must start with access or symbol";
}

sub _access {
    my ($scope, $children) = @_;

    my ($left, $right) = @$children;

    my ($l_arg, $r_arg);
    my ($l_type, $l_val) = @$left;
    my ($r_type, $r_val) = @$right;

    if ($l_type eq SYMBOL) {
        $l_arg = _symbol($scope, $l_val);
    }

    if ($l_type eq OP_ACCESS) {
        $l_arg = _access($scope, $l_val);
    }

    if ($r_type eq OP_ACCESS) {
        die "an access can't be followed directly by another access. the parser admitted an invalid program";
    }

    if ($r_type eq OP_HASHKEY) {
        return _hashkey($scope, $l_arg, $r_val);
    }

    if ($r_type eq OP_ARRAYINDEX) {
        return _arrayindex($scope, $l_arg, $r_val);
    }
}

sub _arrayindex {
    my ($scope, $left, $child) = @_;
    my ($type, $value) = @$child;
    if ($type eq STRING) {
        croak "can't index array with a string";
    }

    my $index;
    if ($type eq NUMBER) {
        $index = $value;
    }

    if ($type eq SYMBOL) {
        my $resolved = _symbol($scope, $value);
        if (!looks_like_number($resolved)) {
            croak "array indexes have to be numbers";
        }
        $index = $resolved;
    }

    if ($type eq OP_ACCESS) {
        my $resolved = _access($scope, $value);
        if (!looks_like_number($resolved)) {
            croak "array indexes have to be numbers";
        }
        $index = $resolved;
    }

    if (defined $index) {
        my $len = scalar @$left;
        # negative indexes need checking too
        if ($len <= $index || ($index < 0 && ((-1 * $index) > $len))) {
            croak "does not exist: array is only $len elements long, but you want position $index";
        }

        return $left->[$index];
    }

    # this should only happen when the parser admits an invalid program. which should never happen. in theory.
    die "array index unexpected contents '$type'. please report this, it's a bug in the parser that this aperture was allowed in";
}

sub _hashkey {
    my ($scope, $left, $child) = @_;
    my ($type, $value) = @$child;

    my $key;
    if ($type eq STRING || $type eq NUMBER) {
        $key = $value;
    }

    if ($type eq SYMBOL) {
        my $resolved = _symbol($scope, $value);
        if (is_ref($resolved)) {
            croak "can't use a ref to key into a hash";
        }

        $key = $resolved;
    }

    if ($type eq OP_ACCESS) {
        my $resolved = _access($scope, $value);
        if (is_ref($resolved)) {
            croak "can't use a ref to key into a hash";
        }

        $key = $resolved;
    }

    if (defined $key) {
        if (!exists $left->{$key}) {
            croak "no such key '$key' in hash";
        }

        return $left->{$key};
    }

    # this should only happen when the parser admits an invalid program. which should never happen. in theory.
    die "hash key unexpected contents '$type'. please report this, it's a bug in the parser that this aperture was allowed in";
}

sub _symbol {
    my ($scope, $name) = @_;

    croak "no symbol '$name' in scope" if !exists $scope->{$name};
    my $val = $scope->{$name};
    if (is_refref($val) || is_scalarref($val)) {
        return $$val;
    }

    return $val;
}

1;
