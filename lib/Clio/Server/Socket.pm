
package Clio::Server::TCP;
# ABSTRACT: Base class for Clio TCP Server

use Moo;

use AnyEvent;
use AnyEvent::Socket qw( tcp_server );

use Data::Dumper;$Data::Dumper::Indent=1;

extends qw( Clio::Server );

with 'Clio::Role::UUIDMaker';

=head1 DESCRIPTION

Clio TCP server.

Consumes the L<Clio::Role::UUIDMaker>.

Extends the L<Clio::Server>.

=method start

Start server and wait for incoming connections.

=cut

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
            $client->write("Too many connections\r\n");
            $clients_manager->disconnect_client( $client->id );
        }
    };

    $log->info("Started ", __PACKAGE__, " on $listen->{host}:$listen->{port}");
    AnyEvent->condvar->recv;
}

1;

