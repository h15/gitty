package Mojolicious::Plugin::MojoM::Base;

use Mojolicious::Plugin::MojoM::Config;

use base qw/Rose::DB::Object/;

sub init_db { Mojolicious::Plugin::MojoM::Config->new() }

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
