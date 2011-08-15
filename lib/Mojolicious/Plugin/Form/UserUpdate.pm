package Mojolicious::Plugin::Form::UserUpdate;

sub new
    {
        my ( $self, $app ) = @_;
        
        $app->form (
            user_update => {
                action  => $app->url_for('users_update'),
                method  => 'post',
                submit  => 'Send',
                
                fields  => [qw/name mail ban_time ban_reason/],
                
                'name'  => {
                    label       => 'Name:',
                    type        => 'text',
                    validators  =>
                    {
                        length  => [3,20],
                        like    => qr/[a-zа-яё0-9]/i,
                    }
                },
                
                'mail'  => {
                    label       => 'E-mail:',
                    type        => 'text',
                    validators  =>
                    {
                        length  => [3,20],
                        like    => qr/[\w\d\-_.]+\@[\w\d\-_.]+\.\w+/,
                    }
                },
                
                'ban_time' => {
                    label       => 'Ban time',
                    type        => 'datetime',
                    validators  =>
                    {
                        like    => qr/\d+-\d+-\d+ \d+:\d+:\d+/,
                    }
                },
                
                'ban_reason' => {
                    label       => 'Ban reason:',
                    type        => 'text',
                    validators  =>
                    {
                        length  => [1,255],
                    }
                },
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

