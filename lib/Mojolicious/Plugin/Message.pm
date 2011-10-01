package Mojolicious::Plugin::Message;
use Mojo::Base 'Mojolicious::Plugin';
use Carp;

our $VERSION = 0.1;

sub register {
    my ( $self, $app ) = @_;
    
    $app->helper(
        # Too much bullets to live.
        fatal => sub {
            my ($self, $message) = @_;
            croak qq/Fatal error: "$message"\n/;
        }
    );
    
    $app->helper(
        # Log and show error.
        error => sub {
            my ($self, $message, $format) = @_;
            $app->log->error($message);
            $self->msg( error => $format => { message => $message } );
        }
    );
    
    $app->helper(
        # Show "Done", be nice.
        done => sub {
            my ($self, $message, $format) = @_;
            $self->msg( done => $format => { message => $message } );
        }
    );
    
    $app->helper(
        # Do not use it directly.
        msg => sub {
            # For example: (self, 'error', 'html',
            # { message => "Die, die, dive with me!" }).
            my ($self, $template, $format, $data) = @_;
            $format ||= 'html';
            
            $self->stash(
                %$data, 
                title => $template
            );
            
            $self->render(template => "message/$template");
            $self->rendered(200);
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

