package Mojolicious::Plugin::User::Controller::Users;

use Mojo::Base 'Mojolicious::Controller';

use Model::User::User;

sub read {
    my $self = shift;
    
	# Does it exist?
	unless ( Model::User::User->new( id => $self->stash('id') )->load(speculative => 1) ) {
	    return $self->error("User with this id doesn't exist!");
	}

	my $user = Model::User::User->new( id => $self->stash('id') )->load;
    
    if ( $self->user->id != 1                         # not Anonymous
        && ( $self->param('id') == $self->user->id    # and Self
             || $self->user->is_admin ) ) {         #  or Admin.
        $self->read_extended($user);
    }
    else {
        $self->stash( user => $user );
        $self->render;
    }
}

sub read_extended {
    my ( $self, $user ) = @_;
    $self->stash( user => $user );
    $self->render( action => 'read_extended' );
}

sub create {
    my $self = shift;
    
    return $self->error('CAPTCHA test failed.') unless $self->captcha;
    
    # Does it exist?
	if ( Model::User::User->new(mail => $self->param('mail'))->load(speculative => 1) ) {
	    return $self->error("User with this id already exists!");
	}
    
    my $key = Digest::MD5::md5_hex(rand);
    
    $self->mail( confirm =>
        $self->param('mail'),
        'Registration',
        { key  => $key, mail => $self->param('mail') }
    );
    
    my $user = Model::User::User->new (
        mail         => $self->param('mail'),
        regdate      => time,
        confirm_time => time + 86400,               # Day for activate
        confirm_key  => $key,
        groups       => '1000',                     # Weakest group
    );
    $user->save;
    
    return $self->done('Check your mail.');
}

sub update {
    my $self = shift;
    
    # Can change?
    unless ( $self->user->id != 1
            && ( $self->param('id') == $self->user->id
                || $self->user->is_admin ) ) {
        return $self->error("Permission denied!");
    }
    
    # Does it exist?
	unless ( Model::User::User->new(id => $self->param('id'))->load(speculative => 1) ) {
	    return $self->error("User with this id doesn't exist!");
	}
    
    my $user = Model::User::User->new( id => $self->param('id') )->load;
       $user->name      ( $self->param('name'      ) ) if defined $self->param('name') && ! defined $user->name;
       $user->mail      ( $self->param('mail'      ) ) if defined $self->param('mail');
       $user->ban_time  ( $self->param('ban_time'  ) ) if defined $self->param('ban_time');
       $user->ban_reason( $self->param('ban_reason') ) if defined $self->param('ban_reason');
       $user->password  ( Digest::MD5::md5_hex( $user->regdate . $self->param('pass') . $self->stash('salt') ) )
                                                       if defined $self->param('pass') && $self->param('pass') eq $self->param('pass2');
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

