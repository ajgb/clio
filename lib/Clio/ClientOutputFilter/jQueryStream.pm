
package Clio::ClientOutputFilter::jQueryStream;
# ABSTRACT: Client output filter for jQueryStream

use Moo::Role;

around 'handshake' => sub {
    my $orig = shift;
    my $self = shift;

    $self->log->trace(__PACKAGE__, " in use for handshake");
    my $msg = $self->id
            .';'.
            " " x 1024
            .';';

    $self->writer->write( $msg );

    $self->$orig( @_ );
};

around 'write' => sub {
    my $orig = shift;
    my $self = shift;

    $self->log->trace(__PACKAGE__, " in use for write");

    $self->$orig(
        map {
            length($_)
            .';'.
            $_
            .";\r\n"
        } @_
    );

};

1;


