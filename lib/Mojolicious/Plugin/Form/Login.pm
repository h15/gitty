package Mojolicious::Plugin::Form::Login;

sub new
    {
        my ( $self, $app ) = @_;
        
        $app->form (
            login => {
                action  => $app->url_for('auths_login'),
                method  => 'post',
                submit  => 'Send',
                
                fields  => [qw/mail password/],
                
                'mail'    => {
                    label       => 'E-mail:',
                    require     => 1,
                    type        => 'text',
                    value       => 'Gitty user',
                    validators  =>
                    {
                        length  => [3,20],
                        like    => qr/[\w\d\-_.]+\@[\w\d\-_.]+\.\w+/,
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
    }

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

