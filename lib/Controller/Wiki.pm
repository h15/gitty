package Controller::Wiki;

use Mojo::Base 'Mojolicious::Controller';

use Model::Wiki::Article;
use Model::Wiki::Revision;

sub article_read {
    my $self = shift;
 
    # Is not exist
    unless ( Model::Wiki::Article->new(id => $self->param('aid'))->load(speculative => 1) ) {
        return $self->redirect_to('wiki_article_form');
    }
    
    my $art = Model::Wiki::Article->new( id => $self->param('aid') )->load;
    my $rev = $art->revision;
    
    $self->stash( page => {
        title  => $art->title,
        text   => $rev->text,
        user   => $rev->user,
        date   => $rev->datetime,
        status => $art->status,
    });
    
    $self->render;
}

sub article_create {
    my $self = shift;
    
    # Is not exist
    if ( Model::Wiki::Article->new(title => $self->param('title'))->load(speculative => 1) ) {
        return $self->redirect_to('wiki_article_form');
    }
    
    # Make new revision, get revision id.
    # Make new article, using revision id, get article id.
    # Update revision's article id.
    my $rev = Model::Wiki::Revision->new (
        text        => $self->param('text'),
        article_id  => 0,
        datetime    => time,
        user        => $self->user->id,
    );
    $rev->save;
    
    my $art = Model::Wiki::Article->new (
        title       => $self->param('title'),
        revision_id => $rev->id,
        status      => $self->user->is_admin ? $self->param('status') : 0,
    );
    $art->save;
    
    $rev->article_id( $art->id );
    $rev->save;
    
    $self->redirect_to( 'wiki_article_read', aid => $art->id );
}

sub article_form { shift->render }

sub article_update {
    my $self = shift;
    
    # Is exist
    unless ( Model::Wiki::Article->new( id => $self->param('aid'))->load(speculative => 1) ) {
        return $self->redirect_to('wiki_article_form');
    }
    
    my $art = Model::Wiki::Article->new( id => $self->param('aid') )->load;
    
    unless ( $self->user->is_admin || $art->status != 1 ) {
        return $self->redirect_to( 'wiki_article_read', aid => $art->id );
    }
    
    # New revision
    my $rev = Model::Wiki::Revision->new (
        text        => $self->param('text'),
        article_id  => $self->param('aid'),
        datetime    => time,
        user        => $self->user->id,
    );
    $rev->save;
    $art->revision_id( $rev->id );
    
    # Update some fields from article.
    if ( $self->param('title') ne $art->title ) {
        # If the article with a same title exists.
        if ( Model::Wiki::Article->new(title => $self->param('title')) ) {
            return $self->redirect_to('wiki_article_form');
        }
        $art->title( $self->param('title') );
    }
    if ( $self->user->is_admin && $self->param('status') ne $art->status ) {
        $art->status( $self->param('status') );
    }
    $art->save;
    
    $self->redirect_to( 'wiki_article_read', aid => $art->id );
}

sub revision_read {
    my $self = shift;    

    # Is exist
    unless ( Model::Wiki::Article ->new( id => $self->param('aid') )->load(speculative => 1)
          && Model::Wiki::Revision->new( id => $self->param('rid') )->load(speculative => 1) ) {
        return $self->redirect_to('wiki_article_form');
    }
    
    my $art = Model::Wiki::Article ->new( id => $self->param('aid') )->load;
    my $rev = Model::Wiki::Revision->new( id => $self->param('rid') )->load;
    
    if ( $rev->article_id != $art->id ) {
        $self->redirect_to( 'wiki_article_read', aid => $art->id );
    }
    
    $self->stash( page => {
        title   => $art->title,
        text    => $rev->text,
        user    => $rev->user,
        date    => $rev->datetime,
        status  => $art->status,
        cur_rev => $art->revision_id,
    });
    
    $self->render;
}

sub revision_update {
    my $self = shift;
    
    # Is exist
    unless ( Model::Wiki::Article ->new( id => $self->param('aid') )->load(speculative => 1)
          && Model::Wiki::Revision->new( id => $self->param('rid') )->load(speculative => 1) ) {
        return $self->redirect_to('wiki_article_form');
    }
    
    my $art = Model::Wiki::Article ->new( id => $self->param('aid') )->load;
    my $rev = Model::Wiki::Revision->new( id => $self->param('rid') )->load;
    
    unless ( $self->user->is_admin || $art->status != 1 ) {
        return $self->redirect_to( 'wiki_article_read', aid => $art->id );
    }
    
    if ( $rev->article_id != $art->id ) {
        $self->redirect_to( 'wiki_article_read', aid => $art->id );
    }
    
    # Mark revision as a current.
    $art->revision_id( $self->param('rid') );
    $art->save;
    
    $self->redirect_to( 'wiki_article_read', $self->param('aid') );
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
