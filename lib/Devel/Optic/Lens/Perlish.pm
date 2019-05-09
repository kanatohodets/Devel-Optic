package Devel::Optic::Lens::Perlish;
use strict;
use warnings;

use Devel::Optic::Lens::Perlish::Parser qw(parse);
use Devel::Optic::Lens::Perlish::Interpreter qw(run);

sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;
}

sub inspect {
    my ($self, $scope, $aperture) = @_;
    my $ast = parse($aperture);
    return run($scope, $ast);
}

1;
