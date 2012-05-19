
package Clio::ClientOutputFilter::LineEnd;
# ABSTRACT: Client output filter appending CRLF

use strict;
use Moo::Role;

=head1 DESCRIPTION

Output filter which will append C<\r\n> if needed.

=method write

Append C<\r\n> if needed.

=cut

around 'write' => sub {
    my $orig = shift;
    my $self = shift;

    $self->log->trace(__PACKAGE__, " in use for write");

    $self->$orig(
        map { $_ !~ /\r\n\z/s ? "$_\r\n" : $_ } @_
    );

};

1;


