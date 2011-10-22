
package Clio::ProcessManager;

use Moo;

use AnyEvent;
use Clio::Process;
use Carp qw( croak );

with 'Clio::Role::HasContext';
with 'Clio::Role::UUIDMaker';

=head1 SYNPOSIS

    my $process_manager = Clio::ProcessManager->new(
        c => $context,
    );

Process manager is created on application start and manages all processes
(L<Clio::Process>).

Based on the configuration starts new listening processes and stops the idle
ones.

=over 4

=item * StartCommands

Number of processes created at the application start.

=item * MinSpareCommands

Minimum number of idle processes.

=item * MaxSpareCommands

Maximum number of idle processes.

=item * MaxCommands

Maximum number of commands running at the same time.

=item * MaxClientsPerCommand

Maximum number of clients per process.

=back

Consumes the L<Clio::Role::HasContext> and the L<Clio::Role::UUIDMaker>.

=cut

=attr processes

    while ( my ($id, $process) = each %{ $process_manager->processes } ) {
        print "Process $id is", ( $process->is_idle ? '' : ' not'), " idle\n";
    }

All managed processes.

=cut

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

=method start

    $process_manager->start;

Starts a number of processes equal to C<StartCommands> and creates the idle
processes maintanace loop.

=cut

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

    while ( my ($uuid, $proc) =  each %{ $self->processes } ) {
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
            $self->stop_process($proc->id);
        }
    }
    $log->debug("Stopped ", ($cur_idle - $max_idle)," idle processes")
        if $cur_idle > $max_idle;

    $self->_start_num_processes(
        $min_idle - $cur_idle,
        $config->{Exec},
    );
}

sub stop_process {
    my ($self, $process_id) = @_;

    $self->c->log->debug("Stopping process $process_id");

    $self->processes->{ $process_id }->stop;

    delete $self->processes->{ $process_id };

}

1;

