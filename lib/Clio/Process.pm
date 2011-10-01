
package Clio::Process;

use Moo;

use AnyEvent;
use AnyEvent::Run;

with 'Clio::Role::HasManager';

has 'id' => (
    is => 'ro',
    required => 1,
);
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

sub stop {
    my $self = shift;
    
    $self->log->debug("Stopping process ", $self->id);

    my $cm = $self->manager->c->server->clients_manager;

    $cm->disconnect_client($_) for keys %{ $self->_clients };

    $self->_handle->destroy;
    $self->_handle(undef);
}

sub write {
    my $self = shift;
        
    $self->log->trace("Process ", $self->id, " writing '@_'");

    $self->_handle->push_write( @_ );
}

sub add_client {
    my ($self, $client) = @_;

    $self->_clients->{ $client->id } = $client;
}

sub remove_client {
    my ($self, $client_id) = @_;

    delete $self->_clients->{ $client_id };
}

sub clients_count {
    my $self = shift;

    return scalar keys %{ $self->_clients };
}

sub is_idle {
    my $self = shift;

    return $self->clients_count == 0;
}

1;

