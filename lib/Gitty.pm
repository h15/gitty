package Gitty;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
    my $app = shift;
    $main::app = $app;
    
    # Load core plugins.
    $app->plugin( $_ ) for qw/ i18n
                               message
                               form
                               config
                               gitosis  /;
    
    # Auto Loader for forms.
    for my $path ( <./lib/Mojolicious/Plugin/Form/*> )
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

