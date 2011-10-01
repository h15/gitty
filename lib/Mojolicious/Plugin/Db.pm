package Mojolicious::Plugin::User;
use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = 0.3;

sub register
    {
        my ( $self, $app ) = @_;
        
        # Get user config.
        unless( $app->config('db') )
        {
            $app->config( db => {
                driver => 'Dbi',
                {
                    driver  => 'MySql',
                    host    => 'localost',
                    user    => 'gitty',
                    password=> 'gitty',
                    dbname  => 'gitty',
                }
            });
        }
        
        my $conf = $app->config('db');
    }

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
