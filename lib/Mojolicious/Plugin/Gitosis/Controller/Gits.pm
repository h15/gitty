package Mojolicious::Plugin::Gitosis::Controller::Gits;
use Mojo::Base 'Mojolicious::Controller';

sub create_repo {
    my $self = shift;
    
    return $self->error('Wrong name format')    if $self->param('name')    !~ $self->gitosis->{word};
    return $self->error('Wrong members format') if $self->param('members') !~ m/(?:\s*\d+\s*)*/;
    return $self->error('Wrong desc format')    if $self->param('desc')    !~ $self->gitosis->{list};
    return $self->error('Already exists')       if $self->gitosis->find_group( $self->param('name') );
    
    my @members = split /\s+/, $self->param('members');
    push @members, $self->user->data->{id} unless grep {$_ == $self->user->data->{id}} @members;
    
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
    
    my $desc = $repo ? $repo->{desc} : '';
    
    $self->stash (
        desc    => $desc,
        members => $group->{members},
        name    => $n
    );
    
    $self->render;
}

sub update {
    my $self = shift;
    
    my $repo  = $self->gitosis->find_repo ( $self->param('repo') );
    my $group = $self->gitosis->find_group( $self->param('repo') );
    
    return $self->error('Repo does not exist') unless $group;
    
    $repo->{desc} = $self->param('desc');
    $group->{members} = [ split /\s+/, $self->param('members') ];
    
    $self->gitosis->save;
    
    $self->redirect_to('gits_read', repo => $self->param('name'));
}

sub add_key {
    my $self = shift;
    
    open F, '>', $self->stash('dir') . 'keydir/' . $self->user->data->{id} . '.pub';
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

