
package Clio::ProcessInputFilter::LineEnd;
# ABSTRACT: Process input filter appending LF

use Moo::Role;

around 'write' => sub {
    my $orig = shift;
    my $self = shift;

    $self->log->trace(__PACKAGE__, " in use for write");

    $self->$orig(
        map { "$_\n" } @_
    );
};

1;


