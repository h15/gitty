package Mojolicious::Plugin::Form::Login;

sub new
    {
        my ( $self, $app ) = @_;
        
        $app->form (
            login => {
                action  => $app->url_for('auths_login'),
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
    }

1;
