
package Clio::ClientOutputFilter::LineEnd;
# ABSTRACT: Client output filter appending CRLF

use Moo::Role;

around 'write' => sub {
    my $orig = shift;
    my $self = shift;

    $self->log->trace(__PACKAGE__, " in use for write");

    $self->$orig(
        map { "$_\r\n" } @_
    );

};

1;


