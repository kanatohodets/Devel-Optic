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

    our @EXPORT_OK = (keys %ast_nodes, qw(lex parse));
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


# %foo->{bar}->[-2]->{$baz->{asdf}}->{'blorg}'}
sub lex {
    my $str   = shift;
    # ignore whitespace
    my @chars = grep { $_ !~ /\s/ } split //, $str;
    my ( $elem, @items );

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

    return \@items;
}

=pod
    %foo
    [SYMBOL, '%foo']

    %foo->{bar}
    [OP_ACCESS, [
        [SYMBOL, '%foo'],
        [OP_HASHKEY,
            [STRING, 'bar']]]]

    %foo->{$bar}
    [OP_ACCESS, [
        [SYMBOL, '%foo'],
        [OP_HASHKEY,
            [SYMBOL, '$bar']]]]

    %foo->{bar}->[-2]->{baz}
    [OP_ACCESS, [
        [OP_ACCESS, [
            [OP_ACCESS, [
                [SYMBOL, '%foo'],
                [OP_HASHKEY,
                    [ STRING, 'bar']]]],
            [OP_ARRAYINDEX,
                [ NUMBER, -2]]]],
        [OP_HASHKEY,
            [STRING, 'baz']]]]

    %foo->{$bar->[0]}
    [OP_ACCESS, [
        [SYMBOL, '%foo'],
        [OP_HASHKEY,
            [OP_ACCESS, [
                [SYMBOL, '$bar'],
                [OP_ARRAYINDEX,
                    [NUMBER, 0]]]]]]]

=cut

sub parse {
    my (@tokens) = @_;
    my $left_node;
    for (my $i = 0; $i <= $#tokens; $i++) {
        my $token = $tokens[$i];

        if ($token =~ /^[\$\%\@]\w+$/) {
            $left_node = [SYMBOL, $token];
            next;
        }

        if ($token =~ /^-?\d+$/) {
            $left_node = [NUMBER, 0+$token];
            next;
        }

        if ($token eq HASHKEY_OPEN) {
            die sprintf "found '%s' outside of a %s operator", HASHKEY_OPEN, ACCESS_OPERATOR;
        }

        if ($token eq HASHKEY_CLOSE) {
            die sprintf "found '%s' outside of a %s operator", HASHKEY_CLOSE, ACCESS_OPERATOR;
        }

        if ($token eq ARRAYINDEX_OPEN) {
            die sprintf "found '%s' outside of a %s operator", ARRAYINDEX_OPEN, ACCESS_OPERATOR;
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
                my $brace_count = 0;
                my $close_index;
                for (my $k = $i; $k <= $#tokens; $k++) {
                    if ($tokens[$k] eq HASHKEY_OPEN) {
                        $brace_count++;
                    }
                    if ($tokens[$k] eq HASHKEY_CLOSE) {
                        $brace_count--;
                        if ($brace_count == 0) {
                            $close_index = $k;
                            last;
                        }
                    }
                }

                die sprintf("invalid syntax: unclosed hash key (missing '%s')", HASHKEY_CLOSE) if !defined $close_index;
                die "invalid syntax: empty hash key" if $close_index == $i+1;

                $right_node = [ OP_HASHKEY, parse(@tokens[$i+1 .. $close_index-1]) ];
                $i = $close_index;
            } elsif ($next eq ARRAYINDEX_OPEN) {
                my $bracket_count = 0;
                my $close_index;
                for (my $k = $i; $k <= $#tokens; $k++) {
                    if ($tokens[$k] eq ARRAYINDEX_OPEN) {
                        $bracket_count++;
                    }

                    if ($tokens[$k] eq ARRAYINDEX_CLOSE) {
                        $bracket_count--;
                        if ($bracket_count == 0) {
                            $close_index = $k;
                            last;
                        }
                    }
                }

                die sprintf("invalid syntax: unclosed array index (missing '%s')", ARRAYINDEX_CLOSE) if !defined $close_index;
                die "invalid syntax: empty array index" if $close_index == $i+1;

                $right_node = [ OP_ARRAYINDEX, parse(@tokens[$i+1 .. $close_index-1]) ];
                $i = $close_index;
            } else {
                die sprintf(
                    "invalid syntax: %s expects either hash key '%sfoo%s' or array index '%s0%s' on the right hand side. found '%s' instead",
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

        # unguarded by a regex because we really mean 'hash key' and that can
        # be all kinds of characters; the lexer deals with quotes and escaped
        # chars already, so we need to accept anything here.
        $left_node = [STRING, $token];
        next;
    }

    return $left_node;
}
