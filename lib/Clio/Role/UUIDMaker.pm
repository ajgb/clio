
package Clio::Role::UUIDMaker;
# ABSTRACT: Role for creating UUID

use Moo::Role;
use Data::UUID;

sub create_uuid {
    return Data::UUID->new->create_str;
}

1;

