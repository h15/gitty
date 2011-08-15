=head1 Mojolicious::Plugin::User::Controller::Auths
User authentication mechanism.
=cut

package Mojolicious::Plugin::User::Controller::Auths;
use Mojo::Base 'Mojolicious::Controller';

sub login
    {
	    my $self = shift;
	    
	    # If validation failed
	    # - show login form and get out here!
	    
	    my $data = $self->form->get('login') || return $self->redirect_to('auths_form');
	    
	    # else
	    # - get data and go ahead.
	    
	    my ( $mail, $password ) = @{ $data->{qw/mail passwd/} };
	    
	    # Does user exist?
	    unless ( $self->model('User')->exists(mail => $mail) )
	    {
	        return $self->error("This pair(e-mail and password) doesn't exist!");
	    }
	    
	    my $user = $self->model('User')->find( mail => $mail );
        
        # Password test
        # hash != md5( regdate + password + salt )

        my $s = $user->regdate
              . $password
              . $self->config('user')->{salt};
        
        if ( $user->password ne Digest::MD5::md5_hex($s) )
        {
            return $self->error( "This pair(e-mail and password) doesn't exist!" );
        }
        
        # Init session.
        $self->session( user_id  => $user->id )
             ->redirect_to( 'users_read', id => $user->id );
    }

sub logout
    {
        shift->session( user_id => '' )->redirect_to('index');
    }

sub mail_request
    {
        my $self = shift;
        
	    # Validation and get.
	    my $data = $self->form->get('mail_request') || return $self->redirect_to('auths_mail_form');
	
	    # Does it exist?
	    unless ( $self->model('User')->exists(mail => $self->param('mail')) )
	    {
	        return $self->error( "This e-mail doesn't exist in data base" );
	    }
	
	    my $confirm_key = Digest::MD5::md5_hex(rand);
	    
	    my $user = $self->model('User')->find( mail => $self->param('mail') );
           $user->confirm_key($confirm_key);
           $user->confirm_time( time + 86400 );
           $user->save;
        
        # Send mail
        $self->mail( confirm =>
            $self->param('mail'), 'Change password',
            { key  => $confirm_key, mail => $self->param('mail') }
        );
        
        return $self->done('Check your mail');
    }

sub mail_confirm
    {
        my $self = shift;
        my $mail = $self->param('mail');
        
	    # Does it exist?
	    unless ( $self->model('User')->exists(mail => $self->param('mail')) )
	    {
	        return $self->error('Auth failed');
	    }
	
	    my $user = $self->model('User')->find(mail => $mail);
        
        if ( $user->confirm_key eq '' )
        {
            return $self->error('You did not request mail login!');
        }
        
        # Too late
        if ( $user->confirm_time > time + 86400 )
        {
            $user->delete;
            return $self->error('Auth failed (too late)!');
        }
        
        # Wrong confirm key
        if ( $user->confirm_key ne $self->param('key') )
        {
            $user->delete;
            return $self->error('Auth failed!');
        }
        
        $user->confirm_key('');
        $user->confirm_time(0);
        $user->mail($mail);
        $user->save;
        
        $self->session( user_id  => $user->id )
             ->redirect_to( 'users_read', id => $user->id );
    }

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

