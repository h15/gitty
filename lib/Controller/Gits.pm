package Controller::Gits;
use Mojo::Base 'Mojolicious::Controller';

sub create_repo {
    my $self = shift;
    
    return $self->error('Must be logged in')    unless $self->user->is_active;
    
    return $self->error('Wrong name format')    if $self->param('name')    !~ $self->gitosis->{word};
    return $self->error('Wrong members format') if $self->param('members') !~ m/(?:\s*\d+\s*)*/;
    return $self->error('Wrong desc format')    if $self->param('desc')    !~ $self->gitosis->{list};
    return $self->error('Already exists')       if $self->gitosis->find_group( $self->param('name') );
    
    my @members = split /\s+/, $self->param('members');
    unshift @members, $self->user->data->{id} unless grep {$_ == $self->user->data->{id}} @members;
    
    @members = map { "u$_" } @members;
    
    $self->gitosis->add_group ({
        $self->param('name') => {
            members => \@members,
            dir => $self->param('name')
        }
    });
    $self->gitosis->add_repo ({
        $self->param('name') => {
            desc => $self->param('desc')
        }
    });
    $self->gitosis->save;
    
    $self->redirect_to('gits_read', repo => $self->param('name'));
}

sub list {
    my $self = shift;
    
    $self->stash (
        repos => [ keys %{$self->gitosis->{groups}} ]
    );
    
    $self->render;
}

sub read {
    my $self = shift;
    my $n = $self->param('repo');
    
    my $repo  = $self->gitosis->find_repo( $n );
    my $group = $self->gitosis->find_group( $n );
    
    return $self->error('Repo does not exist') unless $group;
    
    my $desc = ( $repo ? $repo->{desc} : '' );
    
    $self->stash (
        desc    => $desc,
        members => $group->{members},
        name    => $n
    );
    
    $self->render;
}

sub update {
    my $self = shift;
    
    return $self->error('Must be logged in') unless $self->user->is_active;
    
    my $repo  = $self->gitosis->find_repo ( $self->param('name') );
    my $group = $self->gitosis->find_group( $self->param('name') );
    
    return $self->error('Repo does not exist') unless defined %$group;
    
    my @members = split /\s+/, $self->param('members');
    return $self->error('You are not owner') if 'u'.$self->user->data->{id} ne $members[0];
    
    if ( $repo ) {
        $repo->{desc} = $self->param('desc');
    }
    else {
        $self->gitosis->add_repo({
            $self->param('name') => {
                desc => $self->param('desc')
            }
        });
    }
    
    $group->{members} = \@members;
    
    $self->gitosis->save;
    
    $self->redirect_to('gits_read', repo => $self->param('name'));
}

sub add_key {
    my $self = shift;
    
    return $self->error('Must be logged in') unless $self->user->is_active;
    
    open F, '>', $self->stash('dir') . 'keydir/u' . $self->user->data->{id} . '.pub';
    print F $self->param('key');
    close F;
    
    $self->done('Key added');
}

sub add_server_key {
    my $self = shift;
    
    return $self->error('Must be logged in') unless $self->user->is_active;
    
    open F, '>', $self->stash('dir') . 'keydir/s' . $self->user->data->{id} . '.pub';
    print F $self->param('key');
    close F;
    
    $self->done('Key added');
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

