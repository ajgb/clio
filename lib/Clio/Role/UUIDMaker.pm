
package Clio::Role::UUIDMaker;
# ABSTRACT: Role for creating UUID

use strict;
use Moo::Role;
use Data::UUID;

=head1 DESCRIPTION

UUID generator role. Used to identify processes and clients.

=method create_uuid

Returns UUID in string format

=cut

sub create_uuid {
    return Data::UUID->new->create_str;
}

1;

