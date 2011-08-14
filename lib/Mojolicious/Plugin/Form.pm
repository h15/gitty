=head1 Mojolicious::Plugin::Form
Plugin for Form support
=head2 Overview
Univeral helper for set, get and render forms.
You can see examples in C<Mojolicious::Plugin::Form::Class>.
=cut

package Mojolicious::Plugin::Form;
use Mojo::Base 'Mojolicious::Plugin';

sub register
    {
        my ( $self, $app ) = @_;
        my $class = Mojolicious::Plugin::Form::Class->new($app);
        
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
                    letters => 1,
                    length  => [3,20],
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
=cut

package Mojolicious::Plugin::Form::Class;
use Mojo::Base -base;
use Mojo::ByteStream;

    has forms => sub { {} };    # All forms will be store here.
    has app   => undef;         # Need for error helper.

sub new
    {
        my ( $self, $app ) = @_;
        $self->app($app);
        $self->SUPER::new;
    }

sub _set
    {
        my ( $self, $name, $val ) = @_;
        $self->forms({ %{ $self->forms }, $name => $val });
    }

sub get
    {
        my ( $self, $name ) = @_;
        
        # Form does not exist
        # - still worse than we thought.
        
        unless ( exists $self->forms->{$name} )
        {
            $main::app->error('Some internal error');
            return 0;
        }
        
        my $form = $self->forms->{$name};
        
        # Now we are validating data received from user
        # if future validating will move to special class.
        # Also need some class for adapting data.
        
        # Run validation
        # for all elements defined in {fields}.
        
        # All other fields will be remove.
        # Resistance is futile !!!
        
        my %data;
        
        for my $e ( $form->{fields} )
        {
            $data{ $e } = $main::app->param("$name-$e");
            
            unless ( $self->_validElement($name, $e, $data{ $e }) )
            {
                return $main::app->error
                    ( 'Wrong input param ' . $form->{$e}->{label} );
            }
        }
        
        return \%data;
    }

sub _validElement
    {
        my ( $self, $name, $e, $val ) = @_;
        my $form = $self->forms->{$name};
        
        # Require.
        return 0 if $form->{$e}->{require} && $val eq '';
        
        # Validators.
        return 1 unless defined $form->{$e}->{validators};
        
        my $v = $form->{$e}->{validators};
        
        # Run validation.
        for my $keys ( keys %$v )
        {
            given( $keys )
            {
                when('like')
                {
                    my $regexp = $v->{'like'};
                    return 0 unless $val =~ m/^$regexp$/;
                    break;
                }
                
                when('length')
                {
                    my ( $min, $max ) = $v->{'length'};
                    return 0 if $min > length $val || $max < length $val;
                    break;
                }
            }
        }
        
        return 1;
    }

sub render
    {
        my ( $self, $name ) = @_;
        my $form = $self->forms->{$name};
        my $result;
        
        for my $key ( @{ $form->{fields} } )
        {
            # Like while-each, but order with help $form->{fields}
            my $val = $form->{$key};
            
            # length validator
            my $valid_len   = $val->{validators}->{length} || [0,0];
            my ($min, $max) = @$valid_len;
            
            # is required, get default value
            my $require = defined $val->{require} && $val->{require} != 0 ? 'true' : 'false';
            my $value   = defined $val->{value}   ?  $val->{value} : '';
            
            given( $val->{type} )
            {
                when( 'text' )
                {
                    $result .= sprintf (
                        qq[
                            <dl>
                                <dt>
                                    %s
                                </dt>
                                <dd>
                                    <input type="text" name="%s" value="%s"
                                        onLoad="addToCheck(document.this,%d,%d,%s)">
                                </dd>
                            </dl>
                        ],
                        $val->{label}, "$name-$key", $value, $min, $max, $require
                    );
                    break;
                }
                
                when( 'password' )
                {
                    $result .= sprintf (
                        qq[
                            <dl>
                                <dt>
                                    %s
                                </dt>
                                <dd>
                                    <input type='password' name='%s' value="%s"
                                        onLoad="addToCheck(document.this,%d,%d,%s)">
                                </dd>
                            </dl>
                        ],
                        $val->{label}, "$name-$key", $value, $min, $max, $require
                    );
                    break;
                }
                
                when( 'textarea' )
                {
                    $result .= sprintf (
                        qq[
                            <dl>
                                <dt>
                                    %s
                                </dt>
                                <dd>
                                    <textarea name='%s' onLoad="addToCheck(document.this,%d,%d,%s)">%s</textarea>
                                </dd>
                            </dl>
                        ],
                        $val->{label}, "$name-$key", $min, $max, $require, $value
                    );
                    break;
                }
                
                default
                {
                    $result .= "<div class=error>Unknown element type</div>";
                }
            }
        }
        
        return new Mojo::ByteStream( sprintf ( qq[
            <form method="%s" action="%s" id="%s">
                %s
                <input type="submit" onClick="checkForm(document.this)">
            </form>
        ], $form->{method}, $form->{action}, $name, $result ));
    }


1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

