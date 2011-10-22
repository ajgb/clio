
package Clio::Log;

use Moo;
use Carp qw( croak );

with 'Clio::Role::HasContext';

=head1 SYNOPSIS

Base class for I<Clio::Log::*> implementations.

Consumes the L<Clio::Role::HasContext>.

=cut

sub BUILD {
    my $self = shift;

    $self->init();
}

=method init

Abstract method called at application start.

=cut

sub init { croak "Abstract method"; }

=method logger

Abstract method which should return the log object.

=cut

sub logger { croak "Abstract method"; }

1;

