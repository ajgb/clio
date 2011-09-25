
package Clio::Server;

use Moo;
use Carp qw( croak );
use Clio::Server::ClientsManager;

with 'Clio::Role::HasContext';

has 'host' => (
    is => 'ro',
);
has 'port' => (
    is => 'ro',
);
has 'clients_manager' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_clients_manager',
);

sub start { croak "Abstract method!\n"; }

sub _build_clients_manager {
    my $self = shift;

    return Clio::Server::ClientsManager->new(
        c => $self->c,
    );
};


1;

