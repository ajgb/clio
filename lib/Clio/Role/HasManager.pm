
package Clio::Role::HasManager;
# ABSTRACT: Role for providing manager object

use Moo::Role;

has 'manager' => (
    is => 'ro',
    required => 1,
);

has 'log' => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    default => sub {
        $_[0]->manager->c->log( ref $_[0] );
    }
);


1;

