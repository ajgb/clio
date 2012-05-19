
package Clio::ProcessInputFilter::LineEnd;
# ABSTRACT: Process input filter appending LF

use strict;
use Moo::Role;

=head1 DESCRIPTION

Input filter which will append C<\n> if needed.

=method write

Append C<\n> if needed.

=cut

around 'write' => sub {
    my $orig = shift;
    my $self = shift;

    $self->log->trace(__PACKAGE__, " in use for write");

    $self->$orig(
        map { $_ !~ /\n\z/s ? "$_\n" : $_ } @_
    );
};

1;


