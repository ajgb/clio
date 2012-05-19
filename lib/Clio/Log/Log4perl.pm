
package Clio::Log::Log4perl;
# ABSTRACT: Log4perl log implementation

use strict;
use Moo;
use Log::Log4perl qw( get_logger );

extends qw( Clio::Log );

=head1 DESCRIPTION

Implement L<Log::Log4perl> as logging class.

=cut

=method init

Called during start of application, initializes the logger with
E<lt>LogE<gt>/E<lt>Config<gt> text.

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

Returns the logger.

=cut

sub logger {
    my $self = shift;

    return get_logger(@_);
}


1;

