
package Clio::Log;

use Moo;
use Carp qw( croak );

with 'Clio::Role::HasContext';

sub BUILD {
    my $self = shift;

    $self->init();
}

sub init { croak "Abstract method"; }
sub logger { croak "Abstract method"; }

1;

