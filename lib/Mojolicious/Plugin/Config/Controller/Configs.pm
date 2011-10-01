package Mojolicious::Plugin::Config::Controller::Configs;
use Mojo::Base 'Mojolicious::Controller';

sub index
    {
        my $self = shift;
        my @configs = sort keys %{ $self->config->configs };
        
        $self->stash(
            current => $configs[0],
            configs => \@configs
        );
        
        $self->render( template => 'configs/read' );
    }

sub read
    {
        my $self = shift;
        my $name = $self->param('name');
        
        my @configs = sort keys %{ $self->config->configs };
        
        $name ||= $configs[0];
        
        $self->stash(
            current => $name,
            configs => \@configs
        );
        
        $self->render;
    }
    
sub update
    {
        my $self = shift;
        my $name = $self->param('name');
        
        my %data;
        
        for my $c ( keys %{ $self->config->configs->{$name} } )
        {
            $data{ $c } = $self->param("-$c-input");
        }
        
        $self->config( $name => \%data);
        
        $self->redirect_to('config_read', name => $name);
    }

sub save
    {
        my $self = shift;
           $self->config->save;
           $self->redirect_to('config_index');
    }

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

