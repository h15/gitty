package Mojolicious::Plugin::Config;
use Mojo::Base 'Mojolicious::Plugin';
use Storable qw(freeze thaw);

# Run once.
sub register {
    my ( $self, $app ) = @_;
    my $class = new Mojolicious::Plugin::Config::Class;
    
    # Read config.
    {
        local $/;
        
        open F, './lib/Mojolicious/Plugin/Config/config.dat' or
            $app->fatal( "Use command ./script/gitty install ... to install Gitty.\n".
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
    
    $app->plugin('mojo_m');
    
    # Routes for admin.
    my $r = $app->routes->route('/admin/config')->to( namespace => 'Mojolicious::Plugin::Config::Controller' );
    my $a = $r->bridge('/')->to( cb => sub { shift->user->is_admin } );
       $a->route('/'                      )->via('get' )->to('config#index' )->name('config_index' );
       $a->route('/save/all'              )->via('get' )->to('config#save'  )->name('config_save'  );
       $a->route('/:name', name => qr/\w+/)->via('get' )->to('config#read'  )->name('config_read'  );
       $a->route('/:name', name => qr/\w+/)->via('post')->to('config#update')->name('config_update');
    
    $app->config( hot_plug => {
        config => 1
    });
}

package Mojolicious::Plugin::Config::Class;
use Mojo::Base -base;
use Storable qw(freeze);

has configs => sub { {} };

# Recursive build html tables for config structure.
sub render {
    my ( $self, $config, $parent ) = @_;

    my $ret   = '';
    $parent ||= '';
    $config ||= {};
    
    for my $k ( keys %$config ) {
        $ret .= "<tr><td>$k</td><td name='$parent-$k'>";
        
        # Branch or leaf?
        $ret .= ( ref $config->{$k} ?
            $self->render( $config->{$k}, "$parent-$k" ) :
            "<input value='" . $config->{$k} . "' name='$parent-$k-input'>"
        );
        $ret .= "</td></tr>";
    }
    return "<table>$ret</table>";
}

sub _get {
    my ( $self, $name ) = @_;
    return $self->configs->{$name};
}

sub _set {
    my ( $self, $k, $v ) = @_;
    %{$self->configs} = ( %{$self->configs}, $k, $v );
}

sub save {
    my $self = shift;
    
    {
        open  F, '>./lib/Mojolicious/Plugin/Config/config.dat' or
            die '[-] Can\'t write into ./lib/Mojolicious/Plugin/Config/config.dat';
        print F freeze( $self->configs );
        close F;
    }
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

