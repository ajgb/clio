
package Clio::Client;

use Moo;
use Carp qw( croak );

with 'Clio::Role::HasManager';

has 'id' => (
    is => 'ro',
    required => 1,
);

has '_process' => (
    is => 'rw',
);

sub handshake {}

sub write { croak "Abstract method"; }
sub close { croak "Abstract method"; }

sub attach_to_process {
    my ($self, $process) = @_;

    $self->_process($process);
}

sub disconnect {
    my $self = shift;

    if ( $self->_process ) {
        $self->_process->remove_client( $self->id );
    }

    $self->close;
}

1;

