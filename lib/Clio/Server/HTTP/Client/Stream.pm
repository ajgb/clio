
package Clio::Server::HTTP::Client::Stream;
# ABSTRACT: Clio HTTP Client for streaming connections

use strict;
use Moo;

use Scalar::Util qw( blessed );

extends qw( Clio::Client );

=head1 DESCRIPTION

    # HTTP server with streaming clients
    <Server>
        Listen 0:12345

        Class HTTP

        <Client>
            Class Stream

            OutputFilter LineEnd
        </Client>
    </Server>


HTTP server with streaming capabilities.

Process output is streamed directly to client - the above example can be used
directly in a browser for read only data.

Extends of L<Clio::Client>.

=attr writer

Response callback writer 

=cut

has 'writer' => (
    is => 'rw',
);

=attr req

HTTP request

=cut

has 'req' => (
    is => 'rw',
);

=method write

Write client's message to process.

=cut

sub write {
    my $self = shift;

    $self->log->trace("Stream Client ", $self->id, " writing '@_'");

    eval {
        $self->writer->write( @_ );
    };
    if ( my $e = $@ ) {
        $self->_handle_client_error($e);
    }
}

=method respond

Returns response callback for handling client communication.

Note: POST requests (inputs for process) are separate connections.

=cut


sub respond {
    my ($self, %args) = @_;

    if ( my $input = $args{input} ) {
        my $message = $input->{message};
        $self->_process->write( $message );

        return [ 200, [
            'Content-Type' => 'text/plain; charset=utf-8',
            'Access-Control-Allow-Origin' => '*',
        ], [ "ACK" ] ];
    } else {
        return sub {
            my $respond = shift;

            my $res_status = 200;
            my $res_headers = [
                'Content-Type' => 'text/plain; charset=utf-8',
                'Access-Control-Allow-Origin' => '*',
            ];
            my $writer = $respond->([$res_status, $res_headers]);

            $self->writer( $writer );

            # no middleware is in use, so let's get under the bonnet
            if ( blessed($writer) eq 'Twiggy::Writer' ) {
                $writer->{handle}->on_error(sub {
                    my ($handle, $fatal, $message) = @_;
                    $self->_handle_client_error($message);
                });
            }

            $self->handshake;

            $self->_process->add_client( $self );
        }
    }
}

=method close

Close connection to client

=cut

sub close {
    my $self = shift;

    $self->writer->close;
}

sub _handle_client_error {
    my ($self, $err_msg) = @_;

    my $cid = $self->id;

    $self->log->error("Connection error for client $cid: $err_msg");
    $self->manager->disconnect_client( $cid );
}

=head1 SEE ALSO

=over 4

=item * L<Clio::Server::HTTP::Client::WebSocket>

WebSocket connections.

=item * L<Clio::ClientOutputFilter::jQueryStream>

Example HTML/JavaScript code in C<examples/ajax.html>.

=back

1;

