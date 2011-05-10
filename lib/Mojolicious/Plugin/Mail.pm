package Mojolicious::Plugin::Mail;
use Mojo::Base 'Mojolicious::Plugin';
use MIME::Lite;

our $VERSION = '0.1';

sub register {
    my ( $plugin, $app, $conf ) = @_;
    
    $app->fatal('Config must be defined.') unless defined %$conf;
    
    $app->helper( mail => sub {
        my ( $self, $type, $mail, $title, $data ) = @_;

        return $self->error('Not enough data for mail!') unless defined $type && defined $mail;
        $title ||= '';
        $data  ||= {};

        $self->stash(
            %$data,
            title => $title,
            host  => $config->{site},
        );
        
        my $html = $self->render (
            partial    => 1,
            template   => "mail/$type"
        );
        
        MIME::Lite->new (
            From    => $conf->{from},
            To      => $mail,
            Subject => $self->l($title),
            Type    => 'text/html',
            Data    => $html,
        )->send;
    });
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

