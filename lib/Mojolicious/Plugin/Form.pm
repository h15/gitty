package Mojolicious::Plugin::Form;
use Mojo::Base 'Mojolicious::Plugin';

sub register
{
    my ( $self, $app ) = @_;
    my $class = new Mojolicious::Plugin::Form::Class;
    
    $app->helper (
        form => sub {
            my ($self, $name, $val) = @_;
            
            return $class                unless defined $name;
            return $class->render($name) unless defined $val;
            return $class->_set($name, $val);
        }
    );
}

package Mojolicious::Plugin::Form::Class;
use Mojo::Base -base;
use Mojo::ByteStream;

has forms => sub { {} };

sub _set
{
    my ( $self, $name, $val ) = @_;
    $self->forms({ %{ $self->forms }, $name => $val });
}

sub render
{
    my ( $self, $name ) = @_;
    my $form = $self->forms->{$name};
    my ( $key, $val, $result );
    
    while( ($key, $val) = each %$form )
    {
        # reserved fields
        next if grep { $key eq $_ } qw/action method submit/;
        
        # length validator
        my $valid_len   = $val->{validators}->{length} || [0,0];
        my ($min, $max) = @$valid_len;
        
        # is required, get default value
        my $require = defined $val->{require} && $val->{require} != 0 ? 'true' : 'false';
        my $value   = defined $val->{value} ? $val->{value} : '';
        
        given( $val->{type} )
        {
            when( 'text' )
            {
                $result .= sprintf (
                    qq[<input type="text" name="%s" value="%s" onClick="formCheck(document.this,%d,%d,%s)">],
                    "$name-$key", $value, $min, $max, $require
                );
            }
            
            when( 'password' )
            {
                $result .= sprintf (
                    qq[<input type='password' name='%s' value="%s" onClick="formCheck(document.this,%d,%d,%s)">],
                    "$name-$key", $value, $min, $max, $require
                );
            }
            
            when( 'textarea' )
            {
                $result .= sprintf (
                    qq[<textarea name='%s' onClick="formCheck(document.this,%d,%d,%s)">%s</textarea>],
                    "$name-$key", $min, $max, $require, $value
                );
            }
            
            default { $result .= "<div class=error>Unknown element type</div>" }
        }
    }
    
    return new Mojo::ByteStream( sprintf ( qq[
        <form method="%s" action="%s">
            %s
            <input type="submit">
        </form>
    ], $form->{method}, $form->{action}, $result ));
}

1;

__END__

=head1 Examples

=head2 Make form right here

    # In form file.
    $form = $app->form (
        login => {
            action  => '/user/login',
            method  => 'post',
            submit  => 'Send',
            
            name    => {
                require     => 1,
                type        => 'text',
                value       => 'Gitty user',
                validators  =>
                {
                    letters => 1,
                    length  => [3,20]
                }
            },
            
            password => {
                require     => 1,
                type        => 'password',
                validators  => { length => [8,20] }]
            }
        }
    );
    
    # In view
    <%= form('login') %>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

