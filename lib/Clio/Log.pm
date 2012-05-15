
package Clio::Log;
# ABSTRACT: Abstract base class for Clio::Log::* implementations

use Moo;
use Carp qw( croak );

with 'Clio::Role::HasContext';

=head1 SYNOPSIS

    package Clio::Log::MyPackage;

    use Moo;

    extends qw( Clio::Log );

    sub init { ... }

    sub logger { ... }

=head1 DESCRIPTION

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

