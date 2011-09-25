
package Clio::Server::Socket;

use Moo;

use AnyEvent;
use AnyEvent::Socket qw( tcp_server );

use Data::Dumper;$Data::Dumper::Indent=1;

extends qw( Clio::Server );

with 'Clio::Role::UUIDMaker';

sub start {
    my $self = shift;

    my $config = $self->c->config;

    my $log = $self->c->log;

    my $listen = $config->server_host_port;

    my $clients_manager = $self->clients_manager;
#    print Dumper($config),"\n";

    my $guard = tcp_server $listen->{host}, $listen->{port}, sub {
        my ($fh, $host, $port) = @_;

        my $uuid = $self->create_uuid;

        my $client = $clients_manager->new_client(
            id => $uuid, 
            fh => $fh,
        );

        if ( my $process = $self->c->process_manager->get_first_available ) {

            $client->attach_to_process( $process );
            $process->add_client( $client );
        } else {
            $client->write("No engines available($uuid)\r\n");
            $clients_manager->disconnect_client( $client->id );
        }
    };

    AnyEvent->condvar->recv;
}

1;

