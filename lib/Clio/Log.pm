
package Clio::Log;
# ABSTRACT: Abstract base class for Clio::Log::* implementations

use strict;
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

Base abstract class for Clio::Log::* implementations.

Logging classes are not to be used directly, but via L<Clio> context, as in:

    $c->log->trace( ... );
    $c->log->debug( ... );

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

Abstract method which should return the logger object.

=cut

sub logger { croak "Abstract method"; }

=head1 SEE ALSO

=over 4

=item * L<Clio::Log::Log4perl>

=back

=for Pod::Coverage
BUILD

=cut

1;

