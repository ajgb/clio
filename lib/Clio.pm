
package Clio;
# ABSTRACT: Command Line Input/Output with sockets and HTTP

use strict;
use Moo;

use Clio::Config;
use Clio::ProcessManager;

use Net::Server::Daemonize qw(daemonize);

=head1 DESCRIPTION

Clio will allow you to connect to your command line utilities over network
socket and HTTP.

Please see L<clio> for configuration options and usage.

=head1 INSTALLATION

    cpanm Clio

=attr config_file

Path to Clio config file.

Required.

=cut

has 'config_file' => (
    is => 'ro',
    required => 1,
);

=attr config

L<Clio::Config> object.

=cut

has 'config' => (
    is => 'lazy',
    init_arg => undef,
);

=attr process_manager

L<Clio::ProcessManager> object.

=cut

has 'process_manager' => (
    is => 'lazy',
    init_arg => undef,
);

=attr server

Server object of class specified in configuration.

=cut

has 'server' => (
    is => 'lazy',
    init_arg => undef,
);

has '_logger' => (
    is => 'lazy',
    init_arg => undef,
    builder => '_build_logger',
);

sub _build_config {
    my $self = shift;

    my $config = Clio::Config->new(
        config_file => $self->config_file
    );

    return $config;
}

sub _build_logger {
    my $self = shift;

    my $logger_class = $self->config->logger_class;
    my $logger = $logger_class->new(
        c => $self,
    );
    return $logger;
}

sub _build_process_manager {
    my $self = shift;

    my $proc_mngr = Clio::ProcessManager->new(
        c => $self,
    );

    return $proc_mngr;
}

sub _build_server {
    my $self = shift;

    my $server_class = $self->config->server_class;

    return $server_class->new(
        c => $self,
    );
}

sub BUILD {
    my $self = shift;

    $self->config->process;
};

=method run

Daemonizes if required by configuration.

Starts L<"process_mananager"> and L<"server">.

=cut


sub run {
    my $self = shift;

    $self->_daemonize();

    $self->process_manager->start;

    $self->server->start;
};

=method log

    my $logger = $c->log( $caller);

Returns logger object of class specified by configuration.

=cut

sub log {
    my $self = shift;
    my $caller = shift || caller();

    $self->_logger->logger($caller);
}

sub _daemonize {
    my $self = shift;

    my $log_method;

    my ($user, $group) = @{ $self->config->run_as_user_group };

    return unless defined $user && defined $group;

    # set user
    my $uid = $user =~ /\A\d+\z/ ? $user : getpwnam($user);

    # set group
    my $gid = $group =~ /\A\d+\z/ ? $group : getgrnam($group);

    daemonize( $uid, $gid, $self->config->pid_file );
}

=for Pod::Coverage
BUILD

=cut

1;
