
package Clio::Server;
# ABSTRACT: Base class for Clio::Server::* implementations

use Moo;
use Carp qw( croak );
use Clio::Server::ClientsManager;

with 'Clio::Role::HasContext';

=head1 DESCRIPTION

Base class for I<Clio::Server::*> implementations.

Consumes the L<Clio::Role::HasContext>.

=cut

=attr host

Server host.

=cut

has 'host' => (
    is => 'ro',
);

=attr port

Server port.

=cut

has 'port' => (
    is => 'ro',
);

=attr clients_manager

Holds L<Clio::Server::ClientsManager>.

=cut

has 'clients_manager' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_clients_manager',
);

sub _build_clients_manager {
    my $self = shift;

    return Clio::Server::ClientsManager->new(
        c => $self->c,
    );
};

=method start

Abstract method to start server.

=cut

sub start { croak "Abstract method!\n"; }

1;

