
package Clio::Log::Log4perl;
# ABSTRACT: Log4perl log implementation

use Moo;
use Log::Log4perl qw( get_logger );

extends qw( Clio::Log );

=head1 DESCRIPTION

Logging classes are not to be used directly, but via L<Clio> context, as in:

    $c->log->trace( ... );
    $c->log->debug( ... );

=cut

=method init

Called during start of application, initializes the logger.

=cut

sub init {
    my $self = shift;

    my $config = $self->c->config->LogConfig;

    if ( my $ro_config = $config->{Config} ) {
        my $config_text = join("\n",
            map { "$_ = $ro_config->{$_}" } keys %$ro_config
        );

        Log::Log4perl::init( \$config_text ); 
    }
}

=method logger

Returns the logger (caller aware).

=cut

sub logger {
    my $self = shift;

    return get_logger(@_);
}

=head1 SEE ALSO

=over 4

=item * L<Log4perl>

=back

=cut


1;

