
package Clio::ProcessManager;
# ABSTRACT: Process manager

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

=head1 DESCRIPTION

Process manager is created on application start and manages all processes
(L<Clio::Process>).

Consumes the L<Clio::Role::HasContext> and the L<Clio::Role::UUIDMaker>.

=head1 CONFIGURATION

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

=attr processes

    while ( my ($id, $process) = each %{ $process_manager->processes } ) {
        print "Process $id is", ( $process->is_idle ? '' : ' not'), " idle\n";
    }

Container for all managed processes.

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

=method create_process

    $process_manager->create_process( $cmd );

Create new L<Clio::Process>

=cut

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

=method get_first_available

    $process_manager->get_first_available( %args );

Based on configuration returns first idle process or if none are availble creates a new one.

=cut

sub get_first_available {
    my ($self, %args) = @_;

    my $config = $self->c->config->CommandConfig;
    my $log = $self->c->log;

    if ( my $client_id = $args{client_id} ) {
        my $clients_manager = $self->c->server->clients_manager;
        if ( my $client = $clients_manager->clients->{ $client_id } ) {
            if ( my $proc = $client->_process ) {
                if ( exists $proc->_clients->{ $client_id } ) {
                    $log->trace("Restored connection from client $client_id");
                    return $proc;
                }
            }
        }
    }

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

=method total_count

    my $num_processes = $process_manager->total_count();

Returns number of managed processes.

=cut

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

=method stop_process
    
    my $stopped_process = $process_manager->stop_process( $process_id );

Stops process and managing it.

=cut

sub stop_process {
    my ($self, $process_id) = @_;

    $self->c->log->debug("Stopping process $process_id");

    $self->processes->{ $process_id }->stop;

    delete $self->processes->{ $process_id };

}

1;

