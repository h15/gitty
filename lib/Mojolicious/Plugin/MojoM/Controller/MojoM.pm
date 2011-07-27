package Mojolicious::Plugin::MojoM::Controller::MojoM;
use Mojo::Base 'Mojolicious::Controller';

sub list {
    my $self = shift;
       $self->stash( models => $self->model->models );
       $self->render;
}

sub read {
    my $self = shift;
       $self->stash (
           models  => $self->model($self->param('id'))->range($self->param('start'), $self->param('offset')),
           columns => [ $self->model($self->param('id'))->raw->meta->column_names ]
       );
       
       $self->render;
}

sub row_read {
    my $self = shift;
       $self->stash (
           model   => $self->model( $self->param('id'), $self->param('rid') ),
           columns => [ $self->model($self->param('id'))->raw->meta->column_names ]
       );
       $self->render;
}

sub row_update {
    my $self = shift;
    
    my @cols  = $self->model($self->param('id'))->raw->meta->column_names;
    my $model = $self->model($self->param('id'))->find( id => $self->param('rid') );
    
    grep { $_ ne 'id' } @cols;
    
    map { $model->$_( $self->param("field-$_") ) } @cols
            if grep { defined $self->param("field-$_") } @cols;
    
    $model->save;

    $self->redirect_to (
        mojo_m_row_read =>
        id  => $self->stash('id'),
        rid => $self->param('rid')
    );
}

sub row_delete {
    my $self = shift;
    
    my @columns = $self->model($self->param('id'))->raw->meta->column_names;
    my $model   = $self->model($self->param('id'))->find( id => $self->param('rid') );
       $model->delete;

    $self->redirect_to( mojo_m_read => id => $self->stash('id') );
}

sub row_form {
    my $self = shift;
       $self->stash (
           columns => [ $self->model($self->param('id'))->raw->meta->column_names ]
       );
       $self->render;
}

sub row_create {
    my $self = shift;
    
    my @cols = $self->model($self->param('id'))->raw->meta->column_names;
    grep { $_ ne 'id' } @cols;
    
    my @fields;
    
    for my $c (@cols) {
       push @fields, $c, $self->param("field-$c") if defined $self->param("field-$c");
    }
    
    my $model = $self->model($self->param('id'))->create(@fields);
       $model->save;
    $self->redirect_to( mojo_m_read => id => $self->stash('id') );
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

