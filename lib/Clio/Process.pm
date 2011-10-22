
package Clio::Process;

use Moo;

use AnyEvent;
use AnyEvent::Run;

with 'Clio::Role::HasManager';

=head1 SYNOPSIS

    my $process = Clio::Process->new(
        manager => $process_manager,
        id      => $uuid,
        command => $command,
    );

All processes are managed by the L<Clio::ProcessManager>. Process runs the
C<$command> and writes to the connected clients the command output.

Consumes the L<Clio::Role::HasManager>.

=attr id

Process ID.

=cut

has 'id' => (
    is => 'ro',
    required => 1,
);

=attr command

Command used by the process.

=cut

has 'command' => (
    is => 'ro',
    required => 1,
);

has '_clients' => (
    is => 'ro',
    default => sub { {} },
    init_arg => undef,
);

has '_handle' => (
    is => 'rw',
    init_arg => undef,
);

=method start

    $process->start;

Starts the C<$self-E<gt>command> and passes the command output to the
connected clients.

On any error the process stops the command.

=cut

sub start {
    my $self = shift;

    my $log = $self->log;

    $self->_handle(
        AnyEvent::Run->new(
            cmd      => [ $self->command ],
            autocork => 0,
            no_delay => 1,
            priority => 19,
            on_error  => sub {
                my ($handle, $fatal, $msg) = @_;
                $log->fatal("Process ", $self->id, " error: $msg");
                $self->manager->stop_process( $self->id );
            },
            on_eof  => sub {
                my ($handle) = @_;
                my $eid = $self->id;
                $log->fatal("** [$eid]->ON_EOF **");
                $self->manager->stop_process( $self->id );
            },
        )
    );

    my $reader; $reader = sub {
        my ($handle, $line, $eol) = @_;

        $log->trace("Process ", $self->id ," reading: '$line'");

        for my $cid ( keys %{ $self->{_clients} } ) {
            $log->trace("Process ", $self->id, " writing to client $cid");
            $self->_clients->{$cid}->write( $line );
        }

        $self->_handle->push_read( line => $reader );
    };
    $self->_handle->push_read( line => $reader );
}

=method stop

    $process->stop;

Disconnects the connected clients and stops the command.

Invoked by L<Clio::ProcessManager>.

=cut

sub stop {
    my $self = shift;
    
    $self->log->debug("Stopping process ", $self->id);

    my $cm = $self->manager->c->server->clients_manager;

    $cm->disconnect_client($_) for keys %{ $self->_clients };

    $self->_handle->destroy;
    $self->_handle(undef);
}

=method write

    $process->write( $line );

Writes C<$line> to the C<STDIN> of the command.

Can be altered by the C<InputFilter>I<s>.

=cut

sub write {
    my $self = shift;
        
    $self->log->trace("Process ", $self->id, " writing '@_'");

    $self->_handle->push_write( @_ );
}

=method add_client

    $process->add_client( $client );

Connects C<$client> to the process - from now on the output of the command
will be written to C<$client>.

=cut

sub add_client {
    my ($self, $client) = @_;

    $self->_clients->{ $client->id } = $client;
}

=method remove_client

    $process->remove_client( $client->id );

Disconnects the C<$client> from the process.

=cut

sub remove_client {
    my ($self, $client_id) = @_;

    delete $self->_clients->{ $client_id };
}

=method clients_count

    my $connected_clients = $process->clients_count();

Returns the number of connected clients.

=cut

sub clients_count {
    my $self = shift;

    return scalar keys %{ $self->_clients };
}

=method is_idle

    if ( $process->is_idle ) {
        $process->stop;
    }

Returns true if there are no clients connected, false otherwise.

=cut

sub is_idle {
    my $self = shift;

    return $self->clients_count == 0;
}

1;

