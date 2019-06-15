package Devel::Optic::Lens::Perlish::Constants;
use Exporter qw(import);

use constant {
    DEBUG => $ENV{DEVEL_OPTIC_DEBUG} ? 1 : 0
};

my %ast_nodes;
my %interpreter;
BEGIN {
    %ast_nodes = (
        OP_ACCESS       => DEBUG ? "OP_ACCESS" : 1,
        OP_HASHKEY      => DEBUG ? "OP_HASHKEY" : 2,
        OP_ARRAYINDEX   => DEBUG ? "OP_ARRAYINDEX" : 3,
        SYMBOL          => DEBUG ? "SYMBOL" : 4,
        STRING          => DEBUG ? "STRING" : 5,
        NUMBER          => DEBUG ? "NUMBER" : 6,
    );

    %interpreter = (
        NODE_TYPE => 0,
        NODE_PAYLOAD => 1,
        RAW_DATA_SAMPLE_SIZE => 10,
    );

    our @EXPORT_OK = (keys %ast_nodes, keys %interpreter);
    our %EXPORT_TAGS = (
        all => [keys %ast_nodes, keys %interpreter],
    );
}

use constant {
    %ast_nodes,
    %interpreter,
};

1;
