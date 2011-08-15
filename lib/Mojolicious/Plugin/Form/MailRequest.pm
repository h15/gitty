package Mojolicious::Plugin::Form::MailRequest;

sub new
    {
        my ( $self, $app ) = @_;
        
        $app->form (
            mail_request => {
                action  => $app->url_for('auths_mail_form'),
                method  => 'post',
                submit  => 'Send',
                
                fields  => [qw/e-mail/],
                
                'e-mail'    => {
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

