package Mojolicious::Plugin::Form::Class;
use Mojo::Base -base;
use Mojo::ByteStream;

    has forms => sub { {} };    # All forms will be store here.
    has app   => undef;         # Need for error helper.
    has data  => sub { {} };

sub new
    {
        my ( $self, $app ) = @_;
             $self->SUPER::new;
             $self->app($app);
    }

sub _set
    {
        my ( $self, $name, $val ) = @_;
        $self->forms({ %{ $self->forms }, $name => $val });
    }
    
sub set_data
    {
        shift->data(shift);
    }

sub get
    {
        my ( $self, $name ) = @_;
        
        # Form does not exist
        # - still worse than we thought.
        
        unless ( exists $self->forms->{$name} )
        {
            $self->app->error('Some internal error');
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
        
        for my $e ( @{ $form->{fields} } )
        {
            $data{ $e } = $self->data->{"$name-$e"};
            
            # Run validation.
            unless ( $self->_validElement($name, $e, $data{ $e }) )
            {
                $self->app->error( 'Wrong input param ' . $form->{$e}->{label} );
                
                return 0;
            }
            
            # Run adapter.
            if ( defined $form->{$e}->{adaptors} )
            {
                for my $a ( keys %{ $form->{$e}->{adaptors} } )
                {
                    $data{$e} = $form->{$e}->{adaptors}->{$a}->( $data{$e} );
                }
            }
        }
        
        return \%data;
    }

sub _validElement
    {
        my ( $self, $name, $e, $val ) = @_;
        my $form = $self->forms->{$name};
        
        # Require.
        return 0 if   $form->{$e}->{require} && $val eq '';
        return 1 if ! $form->{$e}->{require} && $val eq '';
        
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
                    return 0 unless $val =~ /^$regexp$/;
                    break;
                }
                
                when('length')
                {
                    my ( $min, $max ) = @{ $v->{'length'} };
                    return 0 if $min > length $val || $max < length $val;
                    break;
                }
            }
        }
        
        return 1;
    }

sub render
    {
        my ( $self, $name, $values ) = @_;
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
            my $require = defined $val->{require} && $val->{require} != 0 ?
                          'true' :
                          'false';
            
            my $value   = defined $val->{value}   ?  $val->{value} : '';
               $value   = $values->{$key} if defined $values->{$key};
            
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
                                <textarea name='%s'
                                    onLoad="addToCheck(document.this,%d,%d,%s)"
                                    >%s</textarea>
                            </dd>
                        </dl>
                        ],
                        $val->{label}, "$name-$key", $min, $max, $require, $value
                    );
                    
                    break;
                }
                
                when( 'datetime' )
                {
                    $result .= sprintf (
                        qq[
                        <dl>
                            <dt>
                                %s
                            </dt>
                            <dd>
                                <input name='%s'
                                onLoad="addToCheck(document.this,null,null,%s)"
                                value='%s'>
                            </dd>
                         </dl>
                        ],
                        $val->{label}, "$name-$key", $require, $value
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

