package Mojolicious::Plugin::Form::UserCreate;

sub new
    {
        my ( $self, $app ) = @_;
        
        $app->form (
            user_create => {
                action  => $app->url_for('users_create'),
                method  => 'post',
                submit  => 'Send',
                
                fields  => [qw/mail/],
                
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

