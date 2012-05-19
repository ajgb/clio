
package Clio::ClientOutputFilter::jQueryStream;
# ABSTRACT: Client output filter for jQueryStream

use strict;
use Moo::Role;

=head1 DESCRIPTION

Output filter for L<jQueryStream 1.2|https://code.google.com/p/jquery-stream/>.

=method handshake

Initial handshake sends client's ID.

=cut

around 'handshake' => sub {
    my $orig = shift;
    my $self = shift;

    $self->log->trace(__PACKAGE__, " in use for handshake");
    my $msg = $self->id
            .';'.
            " " x 1024
            .';';

    $self->writer->write( $msg );

    $self->$orig( @_ );
};

=method write

Wraps message in format required by jQueryStream.

=cut

around 'write' => sub {
    my $orig = shift;
    my $self = shift;

    $self->log->trace(__PACKAGE__, " in use for write");

    $self->$orig(
        map {
            length($_)
            .';'.
            $_
            .";\r\n"
        } @_
    );

};

1;


