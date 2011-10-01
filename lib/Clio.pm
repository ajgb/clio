
package Clio;

use Moo;

use Clio::Config;
use Clio::ProcessManager;

use Data::Dumper;$Data::Dumper::Indent=1;

has 'config' => (
    is => 'rw',
    init_arg => undef,
);

has 'process_manager' => (
    is => 'rw',
    init_arg => undef,
);

has 'server' => (
    is => 'rw',
    init_arg => undef,
);

has '_logger' => (
    is => 'rw',
    init_arg => undef,
);

sub run {
    my ($self, %args) = @_;

    my $config = Clio::Config->new(
        config_file => $args{config_file}
    );
#    print Dumper($config);

    $self->config( $config );

    $self->config->process;

    my $logger_class = $self->config->logger_class;
    my $logger = $logger_class->new(
        c => $self,
    );
    $self->_logger( $logger );

    $self->_become_user_group();

    my $proc_mngr = Clio::ProcessManager->new(
        c => $self,
    );

    $self->process_manager( $proc_mngr );

    $self->process_manager->start;

    my $server_class = $self->config->server_class;

    $self->server(
        $server_class->new(
            c => $self,
        )
    );

    $self->log->debug("About to start");
    $self->server->start;
};

sub log {
    my $self = shift;
    my $caller = shift || caller();

    $self->_logger->logger($caller);
}

sub _become_user_group {
    my $self = shift;

    my ($user, $group) = @{ $self->config->run_as_user_group };
    $user = (getpwuid($<))[0] unless defined $user;

    my $uid = $user =~ /\A\d+\z/ ? $user : getpwnam($user);

    $self->log->debug("Setting user to $uid");

    $< = $> = $uid;

    $group = (getpwuid($<))[3] unless defined $group;
    my $gid = $group =~ /\A\d+\z/ ? $group : getgrnam($group);

    $self->log->debug("Setting group to $gid");

    $( = $) = $gid;
}

1;
