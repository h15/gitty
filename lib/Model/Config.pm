package Model::Config;

use base 'Rose::DB';

__PACKAGE__->use_private_registry;

__PACKAGE__->default_connect_options( mysql_enable_utf8 => 1 );

__PACKAGE__->register_db(
    driver   => 'mysql',
    database => 'gitty',
    host     => 'localhost',
    username => 'gitty',
    password => 'gitty',
);

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
