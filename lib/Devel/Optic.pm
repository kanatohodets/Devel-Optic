use strict;
use warnings;
package Devel::Optic;

use Carp qw(croak);
use Scalar::Util qw(looks_like_number);
use Ref::Util qw(is_arrayref is_hashref is_scalarref is_refref);

use Devel::Size qw(total_size);
use PadWalker qw(peek_my);

sub new {
    my ($class, %params) = @_;
    my $uplevel = $params{uplevel} // 1;

    if (!$uplevel || !looks_like_number($uplevel) || $uplevel < 1) {
        croak "uplevel should be integer >= 1, not '$uplevel'";
    }

    my $self = {
        uplevel => $uplevel,

        # data structures larger than this value (bytes) will be compressed into a sample
        max_size => $params{max_size} // 5120,

        # if our over-size entity is a scalar, how much of the scalar should we export.
        # assumption is that this is a "simple" data structure and trimming it much
        # more aggressively probably won't hurt understanding that much.
        scalar_truncation_size => $params{scalar_truncation_size} // 512,

        # when building a sample, how much of each scalar child to substr
        scalar_sample_size => $params{scalar_sample_size} // 64,

        # how many keys or indicies to display in a sample from an over-size
        # hashref/arrayref
        ref_key_sample_count => $params{ref_key_sample_count} // 4,
    };

    bless $self, $class;
}

sub inspect {
    my ($self, $lens) = @_;
    my $full_picture = $self->full_picture($lens);
    return $self->fit_to_view($full_picture);
}

sub full_picture {
    my ($self, $lens) = @_;
    my $uplevel = $self->{uplevel};


    my @pieces = split '/', $lens;

    croak '$lens must not be empty' if !$lens || !defined $pieces[0];
    my $sigil = substr $pieces[0], 0, 1;
    if (!$sigil || $sigil ne '$' && $sigil ne '%' && $sigil ne '@') {
        croak '$lens must start with a Perl variable name (like "$scalar", "@array", or "%hash")';
    }

    my $var_name = shift @pieces;
    my $scope = peek_my($uplevel);
    croak "variable '$var_name' is not a lexical variable in scope" if !exists $scope->{$var_name};

    my $var = $scope->{$var_name};

    if (is_scalarref($var) || is_refref($var)) {
        $var = ${ $var };
    }

    my $position = $var;
    my $lens_so_far = $var_name;
    while (scalar @pieces) {
        my $key = shift @pieces;
        my $new_lens = $lens_so_far . "/$key";
        if (is_arrayref($position)) {
            if (!looks_like_number($key)) {
                croak "'$lens_so_far' is an array, but '$new_lens' points to a string key";
            }
            my $len = scalar @$position;
            # negative indexes need checking too
            if ($len <= $key || ($key < 0 && ((-1 * $key) > $len))) {
                croak "'$new_lens' does not exist: array '$lens_so_far' is only $len elements long";
            }
            $position = $position->[$key];
        } elsif (is_hashref($position)) {
            if (!exists $position->{$key}) {
                croak "'$new_lens' does not exist: no key '$key' in hash '$lens_so_far'";
            }
            $position = $position->{$key};
        } else {
            my $ref = ref $position || "NOT-A-REF";
            croak "'$lens_so_far' points to ref of type '$ref'. '$lens' points deeper, but Devel::Optic doesn't know how to traverse further";
        }
        $lens_so_far = $new_lens;
    }
    return $position;
}

sub fit_to_view {
    my ($self, $subject) = @_;

    my $max_size = $self->{max_size};
    # The sizing is a bit hand-wavy: please ping me if you have a cool idea in
    # this area. I was hesitant to serialize the data structure just to
    # find the size (seems like a lot of work if it is huge), but maybe that's
    # the way to go. total_size also does work proportional to the depth of the
    # data structure, but it's likely much lighter than serialization.
    my $size = total_size($subject);
    if ($size < $max_size) {
        return $subject;
    }

    # now we're in too-big territory, so we need to come up with a way to get
    # some useful data to the user without showing the whole structure
    my $ref = ref $subject;
    if (!$ref) {
        my $scalar_truncation_size = $self->{scalar_truncation_size};
        # simple scalars we can truncate (PadWalker always returns refs, so
        # this is pretty safe from accidentally substr-ing an array or hash).
        # Also, once we know we're dealing with a gigantic string (or
        # number...), we can trim much more aggressively without hurting user
        # understanding too much.
        return sprintf(
            "%s (truncated to %d bytes; %d bytes in full)",
            substr($subject, 0, $scalar_truncation_size),
            $scalar_truncation_size,
            $size
        );
    }

    my $ref_key_sample_count = $self->{ref_key_sample_count};
    my $scalar_sample_size = $self->{scalar_sample_size};
    my $sample_text = "No sample for type '$ref'";
    if (is_hashref($subject)) {
        my @sample;
        my @keys = keys %$subject;
        my @sample_keys = @keys[0 .. $ref_key_sample_count - 1];
        for my $key (@sample_keys) {
            my $val = $subject->{$key};
            my $val_chunk;
            if (ref $val) {
                $val_chunk = ref $val;
            } else {
                $val_chunk = substr($val, 0, $scalar_sample_size);
            }
            push @sample, sprintf("%s => %s", $key, $val_chunk);
        }
        $sample_text = sprintf("{%s ...} (%d keys / %d bytes)", join(', ', @sample), scalar @keys, $size);
    } elsif (is_arrayref($subject)) {
        my @sample;
        my $total_len = scalar @$subject;
        my $sample_len = $total_len > $ref_key_sample_count ? $ref_key_sample_count : $total_len;
        for (my $i = 0; $i < $sample_len; $i++) {
            my $val = $subject->[$i];
            my $val_chunk;
            if (ref $val) {
                $val_chunk = ref $val;
            } else {
                $val_chunk = substr($val, 0, $scalar_sample_size);
            }
            push @sample, $val_chunk;
        }
        $sample_text = sprintf("[%s ...] (len %d / %d bytes)", join(', ', @sample), $total_len, $size);
    }

    return sprintf("$ref: $sample_text. Exceeds viewing size (%d bytes)", $max_size);
}

1;

=head1 NAME

Devel::Optic - JSON::Pointer meets PadWalker

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use Devel::Optic;
  my $optic = Devel::Optic->new(max_size => 100);
  my $foo = { bar => ['baz', 'blorg', { clang => 'pop' }] };

  # 'pop'
  $optic->inspect('$foo/bar/-1/clang');

  # 'HASH: { bar => ARRAY ...} (1 total keys / 738 bytes). Exceeds viewing size (100 bytes)"
  $optic->inspect('$foo');

=head1 DESCRIPTION

L<Devel::Optic> is a L<borescope|https://en.wikipedia.org/wiki/Borescope> for Perl
programs.

It provides a basic JSON::Pointer-ish path syntax (a 'lens') for extracting bits of
complex data structures from a Perl scope based on the variable name. This is
intended for use by debuggers or similar introspection/observability tools
where the consuming audience is a human troubleshooting a system.

If the data structure selected by the lens is too big, it will summarize the
selected data structure into a short, human-readable message. No attempt is
made to make the summary machine-readable: it should be immediately passed to
a structured logging pipeline.

It takes a caller uplevel and a JSON::Pointer-style 'lens', and returns the
variable or summary of a variable found by that lens for the scope of that
caller level.

=head1 METHODS

=head2 new

  my $o = Devel::Optic->new(%options);

C<%options> may be empty, or contain any of the following keys:

=over 4

=item C<uplevel>

Which Perl scope to view. Default: 1 (scope that C<Devel::Optic> is called from)

=item C<max_size>

Max size, in bytes, of a datastructure that can be viewed without summarization. Default: 5120.

=item C<scalar_truncation_size>

Size, in bytes, that scalar values are truncated to for viewing. Default: 512.

=item C<scalar_sample_size>

Size, in bytes, that scalar children of a summarized data structure are trimmed to for inclusion in the summary. Default: 64.

=item C<ref_key_sample_count>

Number of keys/indices to display when summarizing a hash or arrayref. Default: 4.

=back

=head2 inspect

  my $stuff = { foo => ['a', 'b', 'c'] };
  my $o = Devel::Optic->new;
  # 'a'
  $o->inspect('$stuff/foo/0');

=head2 fit_to_view

    my $some_variable = ['a', 'b', { foo => 'bar' }, [ 'blorg' ] ];

    my $tiny = Devel::Optic->new(max_size => 1); # small to force summarization
    # "ARRAY: [ 'a', 'b', HASH, ARRAY ]"
    $tiny->fit_to_view($some_variable);

    my $normal = Devel::Optic->new();
    # ['a', 'b', { foo => 'bar' }, [ 'blorg' ] ]
    $normal->fit_to_view($some_variable);

This method takes a Perl object/data structure and either returns it unchanged,
or produces a 'squished' summary of that object/data structure. This summary
makes no attempt to be comprehensive: its goal is to maximally aid human
troubleshooting efforts, including efforts to refine a previous invocation of
Devel::Optic with a more specific lens.

=head2 full_picture

This method takes a 'lens' and uses it to extract a data structure from the
L<Devel::Optic>'s C<uplevel>. If the lens points to a variable that does not
exist, L<Devel::Optic> will croak.

=head3 LENS SYNTAX

L<Devel::Optic> uses a very basic JSON::Pointer style path syntax called
a 'lens'.

A lens always starts with a variable name in the scope being picked,
and uses C</> to indicate deeper access to that variable. At each level, the
value should be a key or index that can be used to navigate deeper or identify
the target data.

For example, a lens like this:

    %my_cool_hash/a/1/needle

Traversing a scope like this:

    my %my_cool_hash = (
        a => ["blub", { needle => "find me!", some_other_key => "blorb" }],
        b => "frobnicate"
    );

Will return the value:

    "find me!"

A less selective lens on the same data structure:

    %my_cool_hash/a

Will return that branch of the tree:

    ["blub", { needle => "find me!", some_other_key => "blorb" }]

Other syntactic examples:

    $hash_ref/a/0/3/blorg
    @array/0/foo
    $array_ref/0/foo
    $scalar

=head4 LENS SYNTAX ALTNERATIVES

The 'lens' syntax attempts to provide a reasonable amount of power for
navigating Perl data structures without risking the stability of the system
under inspection.

In other words, while C<eval '$my_cool_hash{a}-E<gt>[1]-E<gt>{needle}'> would
be a much more powerful solution to the problem of navigating Perl data
structures, it opens up all the cans of worms at once.

I'm open to exploring richer syntax in this area as long as it is aligned with
the following goals:

=over 4

=item Simple query model

As a debugging tool, you have enough on your brain just debugging your system.
Second-guessing your query syntax when you get unexpected results is a major
distraction and leads to loss of trust in the tool (I'm looking at you,
ElasticSearch).

=item O(1), not O(n) (or worse)

I'd like to avoid globs or matching syntax that might end up iterating over
unbounded chunks of a data structure. Traversing a small, fixed number of keys
in 'parallel' sounds like a sane extension, but anything which requires
iterating over the entire set of hash keys or array indicies is likely to
surprise when debugging systems with unexpectedly large data structures.

=back

=head1 SEE ALSO

=over 4

=item *

L<PadWalker>

=item *

L<Mojo::JSON::Pointer>

=item *

L<Devel::Probe>

=back

=head1 AUTHOR

  Ben Tyler <btyler@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2019 by Ben Tyler

This is free software; you can redistribute it and/or modify it under the
same terms as the Perl 5 programming language system itself.
