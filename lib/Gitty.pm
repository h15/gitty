package Gitty;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
    my $self = shift;
    
    # Plugins
    $self->plugin('message');
    $self->plugin( sql => {
        host    => 'dbi:mysql:gitty',
        user    => 'gitty',
        passwd  => 'password',
        prefix  => 'gitty__',
    });
    $self->plugin( user => {
        cookies => 'some random string',    # random string for cookie salt;
        confirm => 7,                       # time to live of session in days;
        salt    => 'some random string',    # random string for db salt;
    });
    $self->plugin('captcha');
    $self->plugin( mail => {
        site => 'http://lorcode.org:3000/',
        from => 'no-reply@lorcode.org'
    });
    $self->plugin( gitosis => {
        git_home => '/home/h15/gitosis-admin/'
    });
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

