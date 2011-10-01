package Mojolicious::Plugin::Form;
use Mojo::Base 'Mojolicious::Plugin';
use Mojolicious::Plugin::Form::Class;

sub register
    {
        my ( $self, $app ) = @_;
        my $class = new Mojolicious::Plugin::Form::Class($app);
        
        # Get data from request (GET, POST).
        # Refresh on each request.

        $app->hook (
            before_dispatch => sub
            {
                my $self = shift;
                my %data;
                
                for my $p ( $self->param() )
                {
                    $data{$p} = $self->param($p);
                }
                
                $class->set_data(\%data);
            }
        );
        
        # Mojolicious::Plugin::Form::Class interface.
        # Set, Render and get Class.
        
        $app->helper (
            form => sub
            {
                my ($self, $name, $val) = @_;
                
                return $class                unless defined $name;
                return $class->render($name) unless defined $val;
                return $class->_set($name, $val);
            }
        );
    }

1;

__END__

=head1 Mojolicious::Plugin::Form

Plugin for Form support

=head2 Overview

Univeral helper for set, get and render forms.
You can see examples in C<Mojolicious::Plugin::Form::Class>.

=head1 Mojolicious::Plugin::Form::Class

=head2 Overview

Class for Form base functions.

=head2 Examples

=head3 View

    form (
        login => {
            action  => url_for('auths_login'),
            method  => 'post',
            submit  => 'Send',
            
            fields  => [qw/e-mail password/],
            
            'e-mail'    => {
                like        => qr/[\w\d\-_.]@[\w\d\-_.]\.\w/,
                label       => 'E-mail:',
                require     => 1,
                type        => 'text',
                value       => 'Gitty user',
                validators  =>
                {
                    length  => [3,20],
                },
                adaptors    =>
                {
                    strtodate => sub { str2time( shift ) }
                }
            },
            
            'password'  => {
                label       => 'Password:',
                require     => 1,
                type        => 'password',
                validators  => { length => [8,20] }
            }
        }
    );

=head3 Controller

    my $data = $self->form->get('login');
    my $name = $data->{name};
    my $pass = $data->{password};

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

