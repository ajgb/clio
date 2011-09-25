
package Clio::Log::Log4perl;

use Moo;
use Log::Log4perl qw( get_logger );

extends qw( Clio::Log );

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

sub logger {
    my $self = shift;

    return get_logger(@_);
}


1;

