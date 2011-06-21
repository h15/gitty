package Mojolicious::Plugin::User::Controller::Auths;

use Mojo::Base 'Mojolicious::Controller';

use Model::User::User;

sub login {
	my $self = shift;
	
	return $self->error('CAPTCHA test failed.') unless $self->captcha;
	
	# It's not an e-mail!
	$self->IS( mail => $self->param('mail')	);
	
	# Does it exist?
	unless ( Model::User::User->new( mail => $self->param('mail') )->load(speculative => 1) ) {
	    return $self->error("This pair(e-mail and password) doesn't exist!");
	}
	
	my $user = Model::User::User->new( mail => $self->param('mail') )->load;
    
    # Password test:
    #   hash != md5( regdate + password + salt )
    my $s = $user->regdate . $self->param('passwd') . $self->stash('salt');
    
    if ( $user->password ne Digest::MD5::md5_hex($s) ) {
        return $self->error( "This pair(e-mail and password) doesn't exist!" );
    }
    
    # Init session.
    $self->session (
        user_id  => $user->id,
    )->redirect_to( 'users_read', id => $user->id );
}

sub logout {
    shift->session( user_id => '' )->redirect_to('index');
}

sub mail_request {
    my $self = shift;
    
    return $self->error('CAPTCHA test failed.') unless $self->captcha;
    
	$self->IS( mail => $self->param('mail') );
	
	# Does it exist?
	unless ( Model::User::User->new( mail => $self->param('mail') )->load(speculative => 1) ) {
	    return $self->error( "This e-mail doesn't exist in data base!" );
	}
	
	my $confirm_key = Digest::MD5::md5_hex(rand);
	
	my $user = Model::User::User->new( mail => $self->param('mail') )->load;
       $user->confirm_key($confirm_key);
       $user->confirm_time( time + 86400 );
       $user->save;
    
    # Send mail
    $self->mail( confirm =>
        $self->param('mail'),
        'Change password',
        { key  => $confirm_key, mail => $self->param('mail') }
    );
    
    return $self->done('Check your mail.');
}

sub mail_confirm {
    my $self = shift;
    my $mail = $self->param('mail');
    
	# Does it exist?
	unless ( Model::User::User->new( mail => $self->param('mail') )->load(speculative => 1) ) {
	    return $self->error('Auth failed!');
	}
	
	my $user = Model::User::User->new( mail => $mail )->load;
    
    my $cfg = $self->stash('user');
    
    if ( $user->confirm_key eq '' ) {
        return $self->error('You did not request mail login!');
    }
    # Too late
    if ( $user->confirm_time > time + 86400 ) {
        $user->delete;
        return $self->error('Auth failed (too late)!');
    }
    # Wrong confirm key
    if ( $user->confirm_key ne $self->param('key') ) {
        $user->delete;
        return $self->error('Auth failed!');
    }
    
    $user->confirm_key('');
    $user->confirm_time(0);
    $user->mail($mail);
    $user->save;
    
    $self->session (
        user_id  => $user->id,
    )->redirect_to( 'users_read', id => $user->id );
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

