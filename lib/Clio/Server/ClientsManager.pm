
package Clio::Server::ClientsManager;

use Moo;
use Carp qw( croak );
use Class::Load ();

with 'Clio::Role::HasContext';

has 'clients' => (
    is => 'ro',
    lazy => 1,
    default => sub { +{} },
);

sub new_client {
    my ($self, %args) = @_;

    my $client_class = $self->c->config->server_client_class;
    $self->c->log->debug("Creating new client, class of $client_class");
    Class::Load::load_class($client_class);

    return $self->clients->{ $args{id} } = $client_class->new(
        manager => $self,
        %args
    );
}

sub disconnect_client {
    my ($self, $client_id) = @_;

    $self->c->log->debug("Disconnecting client $client_id");

    $self->clients->{ $client_id }->disconnect;

    delete $self->clients->{ $client_id };
}


sub total_count {
    my $self = shift;

    return scalar keys %{ $self->clients };
}


1;

