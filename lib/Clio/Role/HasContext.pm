
package Clio::Role::HasContext;

use Moo::Role;

has 'c' => (
    is => 'ro',
    required => 1,
);

1;

