package Mojolicious::Plugin::User::Controller::Auths;
use Mojo::Base 'Mojolicious::Controller';

sub login {
	my $self = shift;
	
	return $self->error('CAPTCHA test failed.') unless $self->captcha;
	
	# It's not an e-mail!
	$self->IS( mail => $self->param('mail')	);
	
	# Get accounts by e-mail.
	my $user = $self->data->read_one( users => { mail => $self->param('mail') } );
    
    # If this e-mail does not exist
    # or more than one account has this e-mail.
    return $self->error("This pair(e-mail and password) doesn't exist!") unless defined %$user;
    
    # Password test:
    #   hash != md5( regdate + password + salt )
    my $s = $user->{regdate} . $self->param('passwd') . $self->stash('salt');
    
    if ( $user->{password} ne Digest::MD5::md5_hex($s) ) {
        return $self->error( "This pair(e-mail and password) doesn't exist!" );
    }
    
    # Init session.
    $self->session (
        user_id  => $user->{id},
    )->redirect_to( 'users_read', id => $user->{id} );
}

sub logout {
    shift->session( user_id => '' )->redirect_to('index');
}

sub mail_request {
    my $self = shift;
    
    return $self->error('CAPTCHA test failed.') unless $self->captcha;
    
	$self->IS( mail => $self->param('mail') );
	
    # Get accounts by e-mail.
	my $user = $self->data->read_one( users => {mail => $self->param('mail')} );
    
    # if 0 - all fine
    return $self->error( "This e-mail doesn't exist in data base!" ) unless defined %$user;
    
    # Generate and save confirm key.
    my $confirm_key = Digest::MD5::md5_hex(rand);
    
    $self->data->update( users =>
        {
            confirm_key  => $confirm_key,
            confirm_time => time + 3600 * 24 * $self->joker->jokes->{User}->{config}->{confirm}
        },
        { mail => $self->param('mail') }
    );
    
    # Send mail
    $self->mail->confirm ({
        reason  => 'Change password',
        mail    => $self->param('mail'),
        key     => $confirm_key
    }); 
}

sub mail_confirm {
    my $self = shift;
    my $mail = $self->param('mail');
    
    my $user = $self->data->read_one( users => {
        mail => $mail,
        confirm_key => $self->param('key')
    });
    
    # This pair does not exist.
    return $self->error('Auth failed!') unless defined %$user;
    
    # Too late
    if ( $user->{confirm_time} > time + 86400 * $self->joker->jokes->{User}->{config}->{confirm} ) {
        $self->data->update( user =>
            { confirm_key => '', confirm_time => 0 },
            { mail => $mail }
        );
        return $self->error('Auth failed (too late)!');
    }
    
    my $user = $self->data->read_one(users => {mail => $mail});
    
    $self->session (
        user_id  => $user->{id},
    )->redirect_to( 'users_read', id => $user->{id} );
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

