
package Clio::Server::Socket::Client::Handle;

use Moo;

extends qw(Clio::Client);

use AnyEvent;
use AnyEvent::Handle;

has 'fh' => (
    is => 'ro',
    required => 1,
);

has '_handle' => (
    is => 'rw',
    lazy => 1,
    builder => '_build_handle',
);

sub _build_handle {
    my $self = shift;

    my $manager = $self->manager;

    return AnyEvent::Handle->new(
        fh => $self->fh,
        on_error  => sub {
            my ($handle, $fatal, $msg) = @_;

            my $cid = $self->id;

            $self->log->error("Connection error for client $cid: $msg");

            $manager->disconnect_client( $cid );
        },
    );
}

sub write {
    my $self = shift;

    $self->log->trace("Client ", $self->id, " writing '@_'");

    $self->_handle->push_write( @_ );
}

sub attach_to_process {
    my ($self, $process) = @_;

    $self->log->debug("Attaching process ", $process->id, " to client ", $self->id);

    $self->_process($process);

    my $reader; $reader = sub {
        my ($handle, $cmd, $eol) = @_;

        $self->_process->write( $cmd );

        $self->_handle->push_read( line => $reader );
    };
    $self->_handle->push_read( line => $reader );

}

sub close {
    my $self = shift;

    $self->_handle->destroy;
}


1;

