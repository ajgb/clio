
package Clio::Client;
# ABSTRACT: Base class for Clio::Client::* implementations

use Moo;
use Carp qw( croak );

with 'Clio::Role::HasManager';

=head1 DESCRIPTION

Base class for I<Clio::Client::*> implementations.

Consumes the L<Clio::Role::HasManager>.

=cut

=attr id

    $client = Clio::Client::Implementation->new(
        id => $uuid
    );

Required read-only client identifier.

=cut

has 'id' => (
    is => 'ro',
    required => 1,
);

has '_process' => (
    is => 'rw',
);

=method handshake

Method called once per new client. No-op in base class.

=cut

sub handshake {}

=method write

    $client->write( $msg );

Abstract method used to write to client.

=cut

sub write { croak "Abstract method"; }

=method close

    $client->close();

Abstract method used to close connection with client.

Not to be used directly, see L</"disconnect">.

=cut

sub close { croak "Abstract method"; }

=method attach_to_process

    $client->attach_to_process( $process );

Links a process with a client.

=cut

sub attach_to_process {
    my ($self, $process) = @_;

    $self->_process($process);
}

=method disconnect

    $client->disconnect();

Removes link to connected process and closes the connection.

=cut

sub disconnect {
    my $self = shift;

    if ( $self->_process ) {
        $self->_process->remove_client( $self->id );
    }

    $self->close;
}

=method restore

=cut

sub restore {
    my ($self, %args) = @_;

    $self->$_( $args{$_} ) for keys %args;

    return $self;
}

1;

