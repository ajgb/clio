
package Clio::Role::HasManager;
# ABSTRACT: Role for providing manager object

use strict;
use Moo::Role;

=head1 DESCRIPTION

Provides access to manager object - L<Clio::ProcessManager> for processes and
L<Clio::Server::ClientsManager> for clients.

=attr manager

Returns appropriate manager object.

=cut

has 'manager' => (
    is => 'ro',
    required => 1,
);

=attr log

Helper shortcut to L<Clio's log|Clio/"log"> method via L<"manager"> object.

=cut

has 'log' => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    default => sub {
        $_[0]->manager->c->log( ref $_[0] );
    }
);


1;

