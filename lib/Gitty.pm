package Gitty;
use Mojo::Base 'Mojolicious';

our $VERSION = 0.000005;

# This method will run once at server start
sub startup
    {
        my $app = shift;
        $main::app = $app;
        
        # Load core plugins.
        $app->plugin( $_ ) for qw/ I18N
                                   message
                                   form
                                   config
                                 /;
        
        # Auto Loader for forms.
        for my $path ( <./lib/Gitty/Form/*> )
        {
            my @way = split '/', $path;
               $way[-1] =~ s/\.pm$//;
               
            my $pack = join '::', @way[2..$#way];
            
            eval "require $pack";
            $pack->new($app);
        }
    }

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

