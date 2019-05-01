use strict;
use warnings;
package Devel::Optic::Parser;

use Exporter qw(import);

use constant {
    DEBUG => $ENV{DEVEL_OPTIC_DEBUG} ? 1 : 0
};

my %ast_nodes;
BEGIN {
    %ast_nodes = (
        OP_ACCESS => DEBUG ? "OP_ACCESS" : 1,
        OP_HASHKEY => DEBUG ? "OP_HASHKEY" : 2,
        OP_ARRAYINDEX => DEBUG ? "OP_ARRAYINDEX" : 3,
        SYMBOL => DEBUG ? "SYMBOL" : 4,
        STRING => DEBUG ? "STRING" : 5,
        NUMBER => DEBUG ? "NUMBER" : 6,
    );

    our @EXPORT_OK = (keys %ast_nodes);
    our %EXPORT_TAGS = (
        constants => [keys %ast_nodes],
    );
}

use constant \%ast_nodes;

use constant {
    'ACCESS_OPERATOR'   => '->',
    'HASHKEY_OPEN'      => '{',
    'HASHKEY_CLOSE'     => '}',
    'ARRAYINDEX_OPEN'   => '[',
    'ARRAYINDEX_CLOSE'  => ']',
};

my %symbols = map { $_ => 1 } qw({ } [ ]);

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub parse {
    my ($self, $route) = @_;
    my @tokens = $self->lex($route);
    return _parse_tokens(@tokens);
}

# %foo->{'bar'}->[-2]->{$baz->{'asdf'}}->{'blorg}'}
sub lex {
    my ($self, $str) = @_;

    # ignore whitespace
    my @chars = grep { $_ !~ /\s/ } split //, $str;
    my ( $elem, @items );

    if (scalar @chars == 0) {
        die "invalid syntax: empty spec";
    }

    if ($chars[0] ne '$' && $chars[0] ne '@' && $chars[0] ne '%') {
        die 'invalid syntax: spec must start with a Perl symbol (prefixed by a $, @, or % sigil)';
    }

    my $in_string;
    for ( my $idx = 0; $idx <= $#chars; $idx++ ) {
        my $char     = $chars[$idx];
        my $has_next = $#chars >= $idx + 1;
        my $next     = $chars[ $idx + 1 ];

        # Special case: escaped characters
        if ( $char eq '\\' && $has_next ) {
            $elem .= $next;
            $idx++;
            next;
        }

        # Special case: string handling
        if ( $char eq "'") {
            $in_string = !$in_string;
            $elem .= $char;
            next;
        }

        # Special case: arrow
        if ( !$in_string && $char eq '-' && $has_next ) {
            if ( $next eq '>' ) {
                if (defined $elem) {
                    push @items, $elem;
                    undef $elem;
                }
                $idx++;
                push @items, '->';
                next;
            }
        }

        if ( !$in_string && exists $symbols{$char} ) {
            if (defined $elem) {
                push @items, $elem;
                undef $elem;
            }
            push @items, $char;
            next;
        }

        # Special case: last item
        if ( !$has_next ) {
            $elem .= $char;
            push @items, $elem;
            last; # unnecessary, but more readable, I think
        }

        # Normal case
        $elem .= $char;
    }

    if ($in_string) {
        die "invalid syntax: unclosed string";
    }

    return @items;
}

sub _parse_hash {
    my @tokens = @_;
    my $brace_count = 0;
    my $close_index;
    for (my $i = 0; $i <= $#tokens; $i++) {
        if ($tokens[$i] eq HASHKEY_OPEN) {
            $brace_count++;
        }
        if ($tokens[$i] eq HASHKEY_CLOSE) {
            $brace_count--;
            if ($brace_count == 0) {
                $close_index = $i;
                last;
            }
        }
    }

    die sprintf("invalid syntax: unclosed hash key (missing '%s')", HASHKEY_CLOSE) if !defined $close_index;
    die "invalid syntax: empty hash key" if $close_index == 1;

    return $close_index, [OP_HASHKEY, _parse_tokens(@tokens[1 .. $close_index-1])];
}

sub _parse_array {
    my @tokens = @_;
    my $bracket_count = 0;
    my $close_index;
    for (my $i = 0; $i <= $#tokens; $i++) {
        if ($tokens[$i] eq ARRAYINDEX_OPEN) {
            $bracket_count++;
        }

        if ($tokens[$i] eq ARRAYINDEX_CLOSE) {
            $bracket_count--;
            if ($bracket_count == 0) {
                $close_index = $i;
                last;
            }
        }
    }

    die sprintf("invalid syntax: unclosed array index (missing '%s')", ARRAYINDEX_CLOSE) if !defined $close_index;
    die "invalid syntax: empty array index" if $close_index == 1;

    return $close_index, [OP_ARRAYINDEX, _parse_tokens(@tokens[1 .. $close_index-1])];
}

sub _parse_tokens {
    my (@tokens) = @_;
    my $left_node;
    for (my $i = 0; $i <= $#tokens; $i++) {
        my $token = $tokens[$i];

        if ($token =~ /^[\$\%\@]/) {
            if ($token !~ /^[\$\%\@]\w+$/) {
                die sprintf 'invalid symbol: "%s". symbols must start with a Perl sigil ($, %%, or @) and contain only word characters', $token;
            }

            $left_node = [SYMBOL, $token];
            next;
        }

        if ($token =~ /^-?\d+$/) {
            $left_node = [NUMBER, 0+$token];
            next;
        }

        if ($token eq HASHKEY_OPEN) {
            die sprintf "found '%s' outside of a %s operator. use %s regardless of sigil",
                HASHKEY_OPEN, ACCESS_OPERATOR, ACCESS_OPERATOR;
        }

        if ($token eq HASHKEY_CLOSE) {
            die sprintf "found '%s' outside of a %s operator", HASHKEY_CLOSE, ACCESS_OPERATOR;
        }

        if ($token eq ARRAYINDEX_OPEN) {
            die sprintf "found '%s' outside of a %s operator. use %s regardess of sigil",
                ARRAYINDEX_OPEN, ACCESS_OPERATOR, ACCESS_OPERATOR;
        }

        if ($token eq ARRAYINDEX_CLOSE) {
            die sprintf "found '%s' outside of a %s operator", ARRAYINDEX_CLOSE, ACCESS_OPERATOR;
        }

        if ($token eq ACCESS_OPERATOR) {
            my $next = $tokens[++$i];
            if (!defined $next) {
                die sprintf "invalid syntax: '%s' needs something on the right hand side", ACCESS_OPERATOR;
            }

            my $right_node;
            if ($next eq HASHKEY_OPEN) {
                my ($close_index, $hash_node) = _parse_hash(@tokens[$i .. $#tokens]);
                $right_node = $hash_node;
                $i += $close_index;
            } elsif ($next eq ARRAYINDEX_OPEN) {
                my ($close_index, $array_node) = _parse_array(@tokens[$i .. $#tokens]);
                $right_node = $array_node;
                $i += $close_index;
            } else {
                die sprintf(
                    q|invalid syntax: %s expects either hash key "%s'foo'%s" or array index "%s0%s" on the right hand side. found '%s' instead|,
                    ACCESS_OPERATOR,
                    HASHKEY_OPEN, HASHKEY_CLOSE,
                    ARRAYINDEX_OPEN, ARRAYINDEX_CLOSE,
                    $next,
                );
            }

            if (!defined $left_node) {
                die sprintf("%s requires something on the left side", ACCESS_OPERATOR);
            }

            $left_node = [OP_ACCESS, [
                $left_node,
                $right_node,
            ]];

            next;
        }

        if ($token =~ /^'(.+)'$/) {
            $left_node = [STRING, $1];
            next;
        }

        die "unrecognized token '$token'. hash key strings must be quoted with single quotes"
    }

    return $left_node;
}

1;
