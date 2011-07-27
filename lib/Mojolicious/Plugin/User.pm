package Mojolicious::Plugin::User;
use Mojo::Base 'Mojolicious::Plugin';

use Digest::MD5 "md5_hex";

our $VERSION = 0.3;

sub register {
    my ( $self, $app ) = @_;
    
    unless( $app->config('user') )
    {
        $app->config( user => {
            cookies => 'some random string',
            expiration => 3600 * 24,
            salt => 'some random string',
        });
    }
    
    $app->model('User')->init;
    
    my $conf = $app->config('user');
    my $user = $app->model('User')->find(id => 1);
    
    $app->secret( $conf->{cookies} );
    $app->sessions->default_expiration( $conf->{expiration} );
    
    # Run on any request!
    $app->hook( before_dispatch => sub {
        my $self = shift;
        
        my $id = $self->session('user_id');
        # Anonymous has 1st id.
        $id ||= 1;
        
        $user = $self->model('User')->find( id => $id );
        
        unless ( $user->is_active ) {
            my $ban = $user->ban_reason;
            $user = $self->model('User')->find( id => 1 );
            $user->ban_reason($ban);
        }
    });
    
    $app->helper( user => sub { $user } );
    $app->plugin('captcha');
    
    # Routes
    my $r = $app->routes->route('/user')->to( namespace => 'Mojolicious::Plugin::User::Controller' );
    
    # User CRU(+L)D
    $r->route('/new')->via('post')->to('users#create')->name('users_create');
    $r->route('/new')->via('get')->to( cb => sub { shift->render( template => 'users/form' ) })->name('users_form');
    $r->route('/:id', id => qr/\d+/)->via('get')->to('users#read')->name('users_read');
    $r->route('/list/:id', id => qr/\d*/)->to('users#list')->name('users_list');
    $r->route('/:id', id => qr/\d+/)->via('post')->to('users#update')->name('users_update');
    $r->route('/:id', id => qr/\d+/)->via('delete')->to('users#delete')->name('users_delete');
    
    # Login by mail:
    $r->route('/login/mail/confirm')->to('auths#mail_confirm')->name('auths_mail_confirm');
    $r->route('/login/mail')->via('post')->to('auths#mail_request')->name('auths_mail_request');
    $r->route('/login/mail')->via('get')->to( cb => sub { shift->render( template => 'auths/mail_form' ) } )->name('auths_mail_form');
    # Auth Create and Delete regulary and via mail
    $r->route('/login')->via('post')->to('auths#login')->name('auths_login');
    $r->route('/login')->via('get')->to( cb => sub { shift->render( template => 'auths/form' ) } )->name('auths_form');
    $r->route('/logout')->to('auths#logout')->name('auths_logout');
    
    $app->helper (
        render_user => sub {
            my ( $self, $id ) = @_;
            
            my $user = $self->model('User')->create( id => $id );
            
            return new Mojo::ByteStream (
                '<a href="' . $app->url_for( 'users_read', id => $id ) . '" class="' .
                    ($user->ban_reason ? 'banned' : 'active') .
                '">' . $user->name . "</a>"
            );
        }
    );
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

