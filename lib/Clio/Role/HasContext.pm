
package Clio::Role::HasContext;
# ABSTRACT: Role for providing context

use Moo::Role;

has 'c' => (
    is => 'ro',
    required => 1,
);

1;

