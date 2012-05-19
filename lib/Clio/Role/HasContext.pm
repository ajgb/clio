
package Clio::Role::HasContext;
# ABSTRACT: Role for providing context

use strict;
use Moo::Role;

=head1 DESCRIPTION

Provides access to application context.

=attr c

L<Clio> object.

=cut

has 'c' => (
    is => 'ro',
    required => 1,
);

1;

