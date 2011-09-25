
package Clio::ProcessManager;

use Moo;

use AnyEvent;
use Clio::Process;
use Carp qw( croak );

with 'Clio::Role::HasContext';
with 'Clio::Role::UUIDMaker';

has 'processes' => (
    is => 'ro',
    default => sub { +{} },
);

has '_check_idle_loop' => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    default => sub {
        my $self = shift;
        AnyEvent->timer(
            after    => 2,
            interval => 2,
            cb       => sub {
                $self->_idle_processes_maintenance();
            },
        );
    },
);

sub start {
    my $self = shift;

    my $config = $self->c->config->CommandConfig;
    my $log = $self->c->log;

    $self->_start_num_processes(
        $config->{StartCommands},
        $config->{Exec},
    );
    $self->_check_idle_loop;
}

sub _start_num_processes {
    my ($self, $number, $cmd) = @_;

    return unless $number >= 1;

    my $cv = AnyEvent->condvar;
    $cv->begin;
    for ( 1 .. $number ) {
        $cv->begin;
        my $s; $s = AnyEvent->timer(
            after => 0,
            cb => sub {
                undef $s;
                $self->create_process( $cmd )->start;
                $cv->end;
            }
        );
    }
    $cv->end;
}

sub create_process {
    my ($self, $cmd) = @_;

    my $uuid = $self->create_uuid;
    $self->c->log->debug("Creating process $uuid");

    return $self->processes->{ $uuid } = Clio::Process->new(
        manager => $self,
        id => $uuid,
        command => $cmd,
    );
}

sub get_first_available {
    my $self = shift;

    my $config = $self->c->config->CommandConfig;
    my $log = $self->c->log;

    for my $uuid ( keys %{ $self->processes } ) {
        my $proc = $self->processes->{$uuid};
        if ( ! $config->{MaxClientsPerCommand} ) {
            return $proc;
        }
        elsif ( $proc->clients_count < $config->{MaxClientsPerCommand} ) {
            return $proc;
        }
    }
    if ( $self->total_count < $config->{MaxCommands} ) {
        my $proc = $self->create_process( $config->{Exec} );
        $proc->start;
        return $proc;
    }

    return;
}

sub total_count {
    my $self = shift;

    return scalar keys %{ $self->processes };
}

sub _idle_processes_maintenance {
    my $self = shift;

    my $config = $self->c->config->CommandConfig;
    my $log = $self->c->log;

    my $min_idle = $config->{MinSpareCommands} || 0;
    my $max_idle = $config->{MaxSpareCommands} || 0;

    my $cur_idle = 0;

    for my $uuid ( keys %{ $self->processes } ) {
        my $proc = $self->processes->{$uuid};

        if ( $proc->is_idle && ++$cur_idle > $max_idle ) {
            $proc->stop;

            delete $self->processes->{$uuid};
        }
    }
    $log->debug("Stopped ", ($cur_idle - $max_idle)," idle processes")
        if $cur_idle > $max_idle;

    $self->_start_num_processes(
        $min_idle - $cur_idle,
        $config->{Exec},
    );
}


1;

