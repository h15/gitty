package Mojolicious::Plugin::MojoM::Controller::MojoM;
use Mojo::Base 'Mojolicious::Controller';

sub list {
    my $self = shift;
       $self->stash( models => $self->model->models );
       $self->render;
}

sub read {
    my $self = shift;
    
    my @columns = $self->model($self->param('id'))->raw->meta->column_names;
                      
    $self->stash (
        models  => $self->model($self->param('id'))
                        ->range($self->param('start'), $self->param('offset')),
        columns => \@columns
    );
    $self->render;
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

