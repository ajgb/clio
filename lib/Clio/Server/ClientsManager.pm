
package Clio::Server::ClientsManager;
# ABSTRACT: Clients manager

use Moo;
use Carp qw( croak );
use Class::Load ();

with 'Clio::Role::HasContext';

=head1 SYNOPSIS

    my $clients_manager = Clio::Server::ClientsManager->new(
        c => $context,
    );

=head1 DESCRIPTION

Clients manager is created by L<Clio::Server> to manage incoming connections. 

Class used to create new client object is set by configuration key, eg:

    <Server>
        Class TCP
        <Client>
            Class Handle
            ...
        </Client>
    </Server>

would use L<Clio::Server::TCP::Client::Handle>.

Consumes the L<Clio::Role::HasContext>.

=attr clients

    while ( my ($id, $client) = each %{ $clients_manager->clients } ) {
        print $client->write("Welcome client $id");
    }

All managed clients.

=cut

has 'clients' => (
    is => 'ro',
    lazy => 1,
    default => sub { +{} },
);

=method new_client

    my $client = $client_manager->new_client(
        id => $uuid,
        %class_specific_args
    );

Creates new managed client. Arguments are specific to the class.

=cut

sub new_client {
    my ($self, %args) = @_;

    my $uuid = delete $args{id};

    if ( my $client = $self->clients->{ $uuid } ) {
        return $client->restore( %args );
    }

    my $client_class = $self->c->config->server_client_class;
    $self->c->log->debug("Creating new client, class of $client_class");
    Class::Load::load_class($client_class);

    return $self->clients->{ $uuid } = $client_class->new(
        manager => $self,
        id => $uuid,
        %args
    );
}

=method disconnect_client

    $client_manager->disconnect_client( $client->id );

Disconnects client.

=cut

sub disconnect_client {
    my ($self, $client_id) = @_;

    $self->c->log->debug("Disconnecting client $client_id");

    $self->clients->{ $client_id }->disconnect;

    delete $self->clients->{ $client_id };
}

=method total_count

    my $connected_clients = $clients_manager->total_count;

Total number of connected clients.

=cut

sub total_count {
    my $self = shift;

    return scalar keys %{ $self->clients };
}

1;

