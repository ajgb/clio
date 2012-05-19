
package Clio::Server::HTTP::Client::WebSocket;
# ABSTRACT: Clio HTTP Client for WebSocket connections

use strict;
use Moo;

use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;
use AnyEvent::Handle;

extends qw( Clio::Server::HTTP::Client::Stream );

=head1 DESCRIPTION

Clio HTTP package for handling clients connected over WebSockets.

Extends L<Clio::Server::HTTP::Client::Stream>.

=attr version

WebSocket version of connected client.

=cut

has 'version' => (
    is => 'rw',
);

require AnyEvent::Handle;
AnyEvent::Handle::register_read_type(
    websocket => sub {
        my ($self, $cb, $version) = @_;
        sub {
            exists $_[0]{rbuf} or return;

            my $frame = Protocol::WebSocket::Frame->new(
                buffer => delete $_[0]{rbuf},
                version => $version
            );

            while (my $in = $frame->next) {
                $cb->($_[0], $in);
            }
        
            return 1;
        }
    }
);

=method write

Write client's message to process.

=cut

sub write {
    my $self = shift;

    $self->log->trace("WebSocket client ", $self->id, " writing '@_'");

    my $frame = Protocol::WebSocket::Frame->new(
        version =>  $self->version,
    );
    $frame->append(@_);
    $self->writer->push_write( $frame->to_bytes );
}

=method respond

Returns response callback for handling client communication.

=cut

sub respond {
    my $self = shift;

    my $env = $self->req->env;

    return sub {
        my $respond = shift;

        my $fh = $env->{'psgix.io'}
            or return $respond->([ 501, [ "Content-Type", "text/plain" ], [ "This server does not support psgix.io extension" ] ]);

        my $hs = Protocol::WebSocket::Handshake::Server->new_from_psgi($env);
        unless ( $hs->parse($fh) ) {
            my $err = $hs->error;
            $self->log->fatal("Cannot parse $fh for handshake: $err");
            return [400, [ "Content-Type", "text/plain" ], [$err]];
        }

        my $h = AnyEvent::Handle->new(fh => $fh);
        $self->writer( $h );

        $h->on_error(sub {
            my ($handle, $fatal, $message) = @_;
            $self->_handle_client_error($message);
        });

        $self->version( $hs->version );

        # handshake
        $self->log->trace("Sending handshake (version: ", $hs->version,"): ", $hs->to_string, " to client: ", $self->id);
        $self->writer->push_write($hs->to_string);

        $self->_process->add_client( $self );

        my $reader; $reader = sub {
            my ($handle, $message) = @_;
            
            $self->_process->write( $message );

            $h->push_read( websocket => $self->version => $reader );
        };
        $h->push_read( websocket => $self->version => $reader );
    };
};


1;

