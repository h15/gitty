package Mojolicious::Plugin::Gitosis::Controller::Gits;
use Mojo::Base 'Mojolicious::Controller';

sub create_repo
{
    my $self  = shift;
    my $conf  = $self->config('gitosis');
    my $desc  = $self->param('desc');
    my $users = $self->param('members');
    my $name  = $self->param('name');
    
    $desc ||= 'no comments' if $conf->{allow_empty_description};
    
    #
    #   Validation.
    #
    return $self->error('Must be logged in')    unless $self->user->is_active;
    return $self->error('Wrong name format')    if $name  !~ $self->gitosis->{word};
    return $self->error('Wrong members format') if $users !~ m/(?:\s*\d+\s*)*/;
    return $self->error('Wrong desc format')    if $desc  !~ $self->gitosis->{list};
    return $self->error('Already exists')       if $self->gitosis->find_group( $self->param('name') );
    
    #
    #   Make members list. Add self, if not added.
    #
    my @members = split /\s+/, $users;
       @members = ( @members, $self->user->id )
            unless grep { $_ == 'u' . $self->user->id } @members;
       
       @members = map { $_ =~ /^u/i ? $_ : "u$_" } @members;
    
    #
    #   Add repo.
    #
    $self->gitosis->add_group ({
        $name => {
            members => \@members,
            dir     => $name
        }
    });
    
    $self->gitosis->add_repo ({ $name => { desc => $desc } });
    $self->gitosis->save;
    
    $self->redirect_to('gits_read', repo => $self->param('name'));
}

sub list
{
    my $self = shift;
    my $conf = $self->config('gitosis');
    
    my @repos = keys %{$self->gitosis->{groups}};
       @repos = grep { exists $self->gitosis->{repos}->{$_} } @repos 
            if $conf->{group_is_repo};

    $self->stash( repos => \@repos );
    $self->render;
}

sub read
{
    my $self = shift;
    my $name = $self->param('repo');
    
    my $repo  = $self->gitosis->find_repo ( $name );
    my $group = $self->gitosis->find_group( $name );
    
    return $self->error('Repo does not exist') unless $group;
    
    my $desc = ( $repo ? $repo->{desc} : '' );
    
    $self->stash (
        desc    => $desc,
        members => $group->{members},
        name    => $name
    );
    
    $self->render;
}

sub update
{
    my $self = shift;
    my $name = $self->param('name');
    my $conf = $self->config('gitosis');
        
    #
    #   Validation.
    #
    return $self->error('Must be logged in') unless $self->user->is_active;
    
    my $repo  = $self->gitosis->find_repo ($name);
    my $group = $self->gitosis->find_group($name);
    
    return $self->error('Repo does not exist') unless defined %$group;
    
    my @members = split /\s+/, $self->param('members');
    return $self->error('You are not owner') if 'u' . $self->user->id ne $members[0];
    
    #
    #   Find or create if groups are repos.
    #
    $repo
        ? $repo->{desc} = $self->param('desc')
        : $conf->{group_is_repo}
            ? $self->gitosis->add_repo({ $name => {desc => $self->param('desc')} })
            : return $self->error('Repo does not exist');
    
    $group->{members} = \@members;
    
    $self->gitosis->save;
    
    $self->redirect_to('gits_read', repo => $name);
}

sub add_key {
    my $self = shift;
    
    return $self->error('Must be logged in') unless $self->user->is_active;
    
    open F, '>', $self->stash('dir') . 'keydir/u' . $self->user->id . '.pub';
    print F $self->param('key');
    close F;
    
    $self->done('Key added');
}

sub add_server_key {
    my $self = shift;
    
    return $self->error('Must be logged in') unless $self->user->is_active;
    
    open F, '>', $self->stash('dir') . 'keydir/s' . $self->user->id . '.pub';
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

