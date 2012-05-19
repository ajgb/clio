
package Clio::Config;
# ABSTRACT: Config loader

use strict;
use Moo;

use Config::Any;
use Config::General;
use Carp qw( croak );
use Class::Load ();

use Role::Tiny ();

=head1 DESCRIPTION

Load and parse configuration options for L<Clio>.

=attr config_file

Required path to config file.

=cut


has 'config_file' => (
    is => 'ro',
    required => 1,
);

has '_config' => (
    is => 'rw',
    init_arg => undef,
);

=attr run_as_user_group

Returns user/group used to run Clio.

=cut

has 'run_as_user_group' => (
    is => 'rw',
    init_arg => undef,
);

=attr pid_file

Path to pid file.

=cut

has 'pid_file' => (
    is => 'rw',
    init_arg => undef,
);

=attr server_class

Package used as server.

=cut

has 'server_class' => (
    is => 'rw',
    init_arg => undef,
);

=attr logger_class

Package used for logging.

=cut

has 'logger_class' => (
    is => 'rw',
    init_arg => undef,
);


=attr server_client_class

Package used as client for given server.

=cut

has 'server_client_class' => (
    is => 'rw',
    init_arg => undef,
);

=attr server_host_port

Listening host/port.

=cut

has 'server_host_port' => (
    is => 'rw',
    init_arg => undef,
);

=attr ServerConfig

Stores I<E<lt>ServerE<gt>> config.

=cut


has 'ServerConfig' => (
    is => 'rw',
    init_arg => undef,
);

=attr CommandConfig

Stores I<E<lt>CommandE<gt>> config.

=cut

has 'CommandConfig' => (
    is => 'rw',
    init_arg => undef,
);

=attr ServerClientConfig

Stores I<E<lt>Server/ClientE<gt>> config.

=cut

has 'ServerClientConfig' => (
    is => 'rw',
    init_arg => undef,
);

=attr LogConfig

Stores I<E<lt>LogE<gt>> config.

=cut

has 'LogConfig' => (
    is => 'rw',
    init_arg => undef,
);

sub BUILD {
    my $self = shift;
    
    eval {
        my $conf = Config::Any->load_files(
            {
                files => [ $self->config_file ],
                use_ext => 1,
                flatten_to_hash => 1,
                driver_args => {
                    General => {
                        -UseApacheInclude => 1,
                        -IncludeRelative => 1,
                        -IncludeDirectories => 1,
                        -IncludeGlob => 1,
                    },
                },
            },
        );

        $self->_config( $conf->{ $self->config_file } );
    };
    if (my $e = $@) {
        $e =~ s/ at .+? line \d+\.//;
        die "$e";
    }
}

sub _validate {
    my $self = shift;

    my $cfile = $self->config_file;

    die "<Command> configuration required in $cfile\n"
        unless exists $self->_config->{Command};

    die "<Server> configuration required in $cfile\n"
        unless exists $self->_config->{Server};

    die "<Server><Client> configuration required in $cfile\n"
        unless exists $self->_config->{Server}->{Client};

    die "Multiple <Server> is not supported in $cfile\n"
        unless ref $self->_config->{Server} eq 'HASH';

    die "Multiple <Command> is not supported in $cfile\n"
        unless ref $self->_config->{Command} eq 'HASH';

    die "Multiple <Server><Client> is not supported in $cfile\n"
        unless ref $self->_config->{Server}->{Client} eq 'HASH';

    die "<Command>Exec is required in $cfile\n"
        unless defined $self->_config->{Command}->{Exec};
}

=method process

Process L<"config_file">.

=cut

sub process {
    my $self = shift;

    $self->_validate();

    $self->_process_daemon();
    $self->_process_command();
    $self->_process_server();
    $self->_process_log();
}

sub _class2package {
    my ($self, $prefix, $class) = @_;

    if ( $class =~ /^\+(.*)$/ ) {
        return "$1";
    }

    return "$prefix\::$class";
}

sub _load_class {
    my ($self, $prefix, $class) = @_;

    my $package = $self->_class2package($prefix, $class);
    Class::Load::load_class( $package );

    return $package;
}

sub _process_log {
    my $self = shift;

    my $config = $self->_config->{Log};

    $self->LogConfig( $config );

    my $logger_class = $self->_load_class(
        'Clio::Log', $config->{Class}
    );

    $self->logger_class( $logger_class );
}


sub _process_server {
    my $self = shift;

    my $config = $self->_config->{Server};

    $self->ServerConfig( $config );

    my $server_class = $self->_load_class(
        'Clio::Server', $config->{Class}
    );

    $self->server_class( $server_class );

    my $listen = $config->{Listen};

    my ($host, $port) = split(/:/, $listen);

    $self->server_host_port({
        host => $host,
        port => $port,
    });

    $self->_process_server_client();
}

sub _arrayify {
    my ($self, $val) = @_;

    return () unless defined $val;
    return ref $val eq 'ARRAY' ? @{ $val } : ( $val );
}

sub _load_io_filters {
    my ($self, %args) = @_;

    my @input_filters = $self->_arrayify( $args{config}->{InputFilter} );
    for ( @input_filters ) {
        my $role = $self->_load_class( "$args{filters}InputFilter", $_ );
        Role::Tiny->apply_role_to_package($args{target}, $role );
    }
    my @output_filters = $self->_arrayify( $args{config}->{OutputFilter} );
    for ( @output_filters ) {
        my $role = $self->_load_class( "$args{filters}OutputFilter", $_ );
        Role::Tiny->apply_role_to_package($args{target}, $role );
    }
};

sub _process_daemon {
    my $self = shift;

    my $config = $self->_config->{Daemon};

    $self->run_as_user_group(
        [ @{$config}{qw(User Group)} ]
    );

    $self->pid_file( $config->{PidFile} );
}



sub _process_command {
    my $self = shift;

    my $config = $self->_config->{Command};
    $self->CommandConfig( $config );

    $self->_load_io_filters(
        filters => 'Clio::Process',
        target => 'Clio::Process',
        config => $config
    );
}

sub _process_server_client {
    my ($self) = @_;

    my $config = $self->_config->{Server}->{Client};
    $self->ServerClientConfig( $config );

    my $client_class = $self->_load_class(
        $self->server_class .'::Client', $config->{Class}
    );
    $self->server_client_class( $client_class );

    $self->_load_io_filters(
        filters => 'Clio::Client',
        target => $client_class,
        config => $config
    );
}

=for Pod::Coverage
BUILD

=cut

1;

