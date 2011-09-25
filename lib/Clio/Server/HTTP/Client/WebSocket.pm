
package Clio::Server::HTTP::Client::WebSocket;

use Moo;

use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;
use AnyEvent::Handle;

use Data::Dumper;$Data::Dumper::Indent=1;

extends qw( Clio::Server::HTTP::Client::Stream );

has '_frame' => (
    is => 'rw',
);

require AnyEvent::Handle;
AnyEvent::Handle::register_read_type(
    websocket => sub {
        my ($self, $cb) = @_;
        sub {
            exists $_[0]{rbuf} or return;
            $_[0]{rbuf} =~ s/^\x00([^\xff]*)\xff// or return;

            $cb->($_[0], $1);
            
            return 1;
        }
    }
);

sub write {
    my $self = shift;

    $self->log->trace("Client ", $self->id, " writing '@_'");

    $self->_frame->append( map { "\x00$_\xff" } @_ );

    while (my $message = $self->_frame->next) {
        my $msg = Protocol::WebSocket::Frame->new(
            buffer => $message,
            version => $self->_frame->version,
        )->to_bytes;

        $self->writer->push_write( $msg );
    }
}

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

        $self->_frame(
            Protocol::WebSocket::Frame->new(
                version => $hs->version
            )
        );

        # handshake
        $self->writer->push_write($hs->to_string);

        $self->_process->add_client( $self );

        my $reader; $reader = sub {
            my ($handle, $message) = @_;
            
            $self->_process->write( $message );

            $h->push_read( websocket => $reader );
        };
        $h->push_read( websocket => $reader );
    };
};


1;

