
package Clio;
# ABSTRACT: Command Line Input/Output with sockets and HTTP

use Moo;

use Clio::Config;
use Clio::ProcessManager;

use DDP;

has 'config' => (
    is => 'lazy',
    init_arg => undef,
);

has 'process_manager' => (
    is => 'lazy',
    init_arg => undef,
);

has 'server' => (
    is => 'lazy',
    init_arg => undef,
);

has '_logger' => (
    is => 'lazy',
    init_arg => undef,
    builder => '_build_logger',
);

has 'config_file' => (
    is => 'ro',
    required => 1,
);

sub _build_config {
    my $self = shift;

    my $config = Clio::Config->new(
        config_file => $self->config_file
    );
#    print p($config);

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

    $self->_set_user_group();

    $self->process_manager->start;
};

sub run {
    my $self = shift;

    $self->log->debug("About to start");

    $self->server->start;
};


sub log {
    my $self = shift;
    my $caller = shift || caller();

    $self->_logger->logger($caller);
}

sub _set_user_group {
    my $self = shift;

    my $log_method;

    my ($user, $group) = @{ $self->config->run_as_user_group };

    # set user
    $user = (getpwuid($<))[0] unless defined $user;
    my $uid = $user =~ /\A\d+\z/ ? $user : getpwnam($user);

    $< = $> = $uid;
    $log_method = $! ? "error" : "debug";
    $self->log->$log_method("Setting user to $uid", ( $! ? " failed: $!" : ''));

    # set group
    $group = (getpwuid($<))[3] unless defined $group;
    my $gid = $group =~ /\A\d+\z/ ? $group : getgrnam($group);

    $( = $) = $gid;
    $log_method = $! ? "error" : "debug";
    $self->log->$log_method("Setting group to $gid", ( $! ? " failed: $!" : ''));
}

1;
