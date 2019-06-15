package Devel::Optic::Lens::Perlish;
use strict;
use warnings;

use Devel::Optic::Lens::Perlish::Parser qw(parse);
use Devel::Optic::Lens::Perlish::Interpreter qw(run);

our @CARP_NOT = qw(Devel::Optic);
sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;
}

sub inspect {
    my ($self, $scope, $query) = @_;
    my $ast = parse($query);
    return run($scope, $ast);
}

1;
