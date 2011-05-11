package Mojolicious::Plugin::User::Controller::Users;
use Mojo::Base 'Mojolicious::Controller';

sub read {
    my $self = shift;
    
	# Get accounts by id.
	my $user = $self->data->read_one( users => { id => $self->stash('id') } );
    
    return $self->error("User with this id doesn't exist!") unless defined %$user;
    
    if ( $self->user->data->{id} != 1                         # not Anonymous
        && ( $self->param('id') == $self->user->data->{id}    # and Self
             || $self->user->is_admin()                       #  or Admin.
        ) ) {
        $self->read_extended($user);
    }
    else {
        $self->stash(user => $user);
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
    
    my $key = Digest::MD5::md5_hex(rand);
    
    my $user = $self->data->read_one( users => {mail => $self->param('mail')} );
    
    return $self->redirect_to('users_form') if defined %$user;
    
    $self->mail( confirm =>
        $self->param('mail'),
        'Registration',
        {
            key  => $key,
            mail => $self->param('mail')
        }
    );
    
    my $cfg = $self->stash('user');
    
    $self->data->create( users => {
        mail    => $self->param('mail'),
        regdate => time,
        confirm_time => time + 86400 * $cfg->{confirm},
        confirm_key  => $key
    });
    
    return $self->done('Check your mail.');
}

sub update {
    my $self = shift;
    
	# Get accounts by id.
	my $user = $self->data->read_one( users => {id => $self->stash('id')} );
	
    return $self->error("User with this id doesn't exist!") unless defined %$user;
    
    unless ( $self->user->data->{id} != 1
        && ( $self->param('id') == $self->user->data->{id}
            || $self->user->is_admin()
        ) ) {
        return $self->error("Permission denied!")
    }
    
    # Parse query.
    my %q;
    
    %q = ( %q, name => $self->param('name') ) if defined $self->param('name') && ! defined $user->{'name'};
    %q = ( %q, mail => $self->param('mail') ) if defined $self->param('mail');
    %q = ( %q, ban_time   => $self->param('ban_time') )   if defined $self->param('ban_time');
    %q = ( %q, ban_reason => $self->param('ban_reason') ) if defined $self->param('ban_reason');
    
    if ( defined $self->param('pass') && $self->param('pass') eq $self->param('pass2') ) {
        my $s = $user->{regdate} . $self->param('pass') . $self->stash('salt');
        %q = ( %q, password => Digest::MD5::md5_hex($s) )
    }
    
    $self->data->update( users =>
        \%q,
        { id => $self->stash('id') }
    );
    
    $self->redirect_to( 'users_read', id => $self->stash('id') );
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

