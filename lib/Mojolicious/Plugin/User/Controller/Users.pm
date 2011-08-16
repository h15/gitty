package Mojolicious::Plugin::User::Controller::Users;
use Mojo::Base 'Mojolicious::Controller';

sub read
    {
        my $self = shift;
        
	    # Does it exist?
	    unless ( $self->model('User')->exists(id => $self->param('id')) )
	    {
	        return $self->error("User with this id doesn't exist!");
	    }
        
	    my $user = $self->model('User')->find(id => $self->param('id'));
        
        # not Anonymous ( and Self or Admin )
        if ( $self->user->id != 1 && ( $self->param('id') == $self->user->id || $self->user->is_admin ) )
        {
            $self->read_extended($user);
        }
        else
        {
            $self->stash( user => $user );
            $self->render;
        }
    }

sub read_extended
    {
        my( $self, $user ) = @_;
            $self->stash( user => $user );
            $self->render( action => 'read_extended' );
    }

sub create
    {
        my $self = shift;
        my $conf = $self->config('user');
        
        # Define it in configurator interface.
        # Deny create new user for all who is not admin.
        
        return $self->error('Registration disabled')
               unless $conf->{enable_registration} || $self->user->is_admin;
        
        # Valid and get data from client.
        # If it's crap - return to form.
        
        my $data = $self->form->get('user_create') || return $self->redirect_to('users_form');
        
        # Does it exist?
	    if ( $self->model('User')->exists( mail => $data->{mail} ) ) {
	        return $self->error("User with this id already exists!");
	    }
        
        # Generate confirm key.
        # Will use twice.
        
        my $key = Digest::MD5::md5_hex(rand);
        
        $self->mail( confirm =>
            $data->{mail},
            'Registration',
            { key  => $key, mail => $data->{mail} }
        );
        
        my $user = $self->model('User')->create (
            mail         => $data->{mail},
            regdate      => time,
            confirm_time => time + 86400,               # Day for activate
            confirm_key  => $key,
            groups       => '1000',                     # Weakest group
        );
        $user->save;
        
        return $self->done('Check your mail.');
    }

sub update
    {
        my $self = shift;
        
        # Can change?
        unless ( $self->user->id != 1 && ( $self->param('id') == $self->user->id || $self->user->is_admin ) )
        {
            return $self->error("Permission denied!");
        }
        
        # Does it exist?
	    unless ( $self->model('User')->exists(id => $self->param('id')) ) {
	        return $self->error("User with this id doesn't exist!");
	    }
        
        my $data = $self->form->get('user_update') ||
            return $self->redirect_to( 'users_read', id => $self->param('id') );
        
        my $user = $self->model('User')->find(id => $self->param('id'));
        
        for ( qw/name mail ban_time ban_reason/ )
        {
           $user->$_( $data->{$_} ) if $data->{$_};
        }
        
        $user->save;
        
        $self->redirect_to( 'users_read', id => $self->stash('id') );
    }

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

