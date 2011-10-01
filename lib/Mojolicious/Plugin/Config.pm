package Mojolicious::Plugin::Config;
use Mojo::Base 'Mojolicious::Plugin';

use Storable qw(freeze thaw);
use Mojolicious::Plugin::Config::Class;

# Run once.
sub register
    {
        my ( $self, $app ) = @_;
        my $class = new Mojolicious::Plugin::Config::Class;
        
        # Read config.
        {
            local $/;
            
            open F, './lib/Mojolicious/Plugin/Config/config.dat' or
                $app->fatal( "Use command ./script/gitty install ".
                             "... to install Gitty.\n".
                             "Read more in README." );
            my $a = <F>;
            close F;
            
            $class->configs( thaw $a );
        }
        
        # Get 
        $app->helper (
            config => sub {
                my ($self, $name, $val) = @_;
                
                return $class unless defined $name;
                
                defined $val
                    ? $class->_set( $name, $val )
                    : $class->_get( $name );
            }
        );
        
        $app->plugin('db');
        
        # Routes for admin.
        my $r = $app->routes->route('/admin/config')
                    ->to( namespace => 'Mojolicious::Plugin::Config::Controller' );
        my $a = $r->bridge('/')->to( cb => sub { shift->user->is_admin } );
           $a->route('/')->via('get')->to('configs#index')
             ->name('config_index');
           $a->route('/save/all')->via('get')->to('configs#save')
             ->name('config_save');
           $a->route('/:name', name => qr/\w+/)->via('get')->to('configs#read')
             ->name('config_read'  );
           $a->route('/:name', name => qr/\w+/)->via('post')->to('configs#update')
             ->name('config_update');
        
        $app->config( hot_plug => {
            config => 1
        });
    }

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

