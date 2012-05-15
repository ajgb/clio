
package Clio::Server::HTTP;
# ABSTRACT: Base class for Clio HTTP Server (Plack based)

use Moo;

use AnyEvent;
use Twiggy::Server;
use Plack::Request;
use Plack::Util;

use Data::Dumper;$Data::Dumper::Indent=1;

extends qw( Clio::Server );

with 'Clio::Role::UUIDMaker';

=head1 DESCRIPTION

Clio HTTP server.

Consumes the L<Clio::Role::UUIDMaker>.

Extends the L<Clio::Server>.

=method start

Start server and wait for incoming connections.

=cut

sub start {
    my $self = shift;

    my $listen = $self->c->config->server_host_port;

    my $twiggy = Twiggy::Server->new(
        %{ $listen }
    );

    $self->c->log->info(
        "Started ", __PACKAGE__, " on $listen->{host}:$listen->{port}"
    );
    $twiggy->run( $self->build_app );
}

=method build_app

Builds Plack application and optionally wrapps it with application specified
in configuration (C<Builder>).

=cut

sub build_app {
    my $self = shift;

    my $config = $self->c->config->ServerConfig;

    my $app = $self->to_app;
    if ( my $builder = $config->{Builder} ) {
        my $wrapper = Plack::Util::load_psgi($builder);

        $app = $wrapper->($app);
    }

    return $app;
}

=method to_app

Creates Plack application.

=cut

sub to_app {
    my $self = shift;

    my $log = $self->c->log;

    sub {
        my ($env) = @_;

        my $req = Plack::Request->new( $env );
        print Dumper($env);

        my %proc_manager_args;
        my $post_data;
        if ( $req->method eq 'POST' ) {
            $post_data = $req->body_parameters;
            print "post_data: ", Dumper($post_data), "\n";
            $proc_manager_args{client_id} = $post_data->{'metadata.id'}
                if exists $post_data->{'metadata.id'};
        }

        my $process = $self->c->process_manager->get_first_available(
            %proc_manager_args
        );
        if ( $process ) {
            $log->debug("got process: ". $process->id );

            my $uuid = $self->create_uuid;

            $log->debug("new client(". $req->address .") id: $uuid");

            my $client = $self->clients_manager->new_client(
                id => $uuid,
                req => $req,
            );

            $client->attach_to_process( $process );

            return $client->respond(
                input => $post_data
            );
        }

        return [ 503, [
            'Content-Type' => 'text/plain; charset=utf-8',
            'Access-Control-Allow-Origin' => '*',
        ], [ "No engines available" ] ];
    }
}

1;



