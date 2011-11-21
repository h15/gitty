package Mojolicious::Plugin::MojoM::Model::Ban;
use base 'Mojolicious::Plugin::MojoM::Base';

=head1 MySQL

    create table `ban`
    (
        `id`        int(11) unsigned not null auto_increment primary key,
        `desc`      varchar(255) character set utf8 collate utf8_general_ci not null,
        `userId`    int(11) unsigned not null,
        `time`      int(11) unsigned not null default 0,
        `expair`    int(11) unsigned not null,
        
        FOREIGN KEY (`userId`)  REFERENCES `user`(`id`)
    );

=cut

    __PACKAGE__->meta->setup
    (
        table      => 'ban',
        
        columns    =>
        [
            id           => { type => 'serial' , not_null => 1 },
            desc         => { type => 'varchar', not_null => 1, length => 255 },
            userId       => { type => 'integer', not_null => 1, length => 11  },
            time         => { type => 'integer', not_null => 1, length => 11, default => 0 },
            expair       => { type => 'integer', not_null => 1, length => 11  },
        ],
        
        pk_columns => 'id',
        
        foreign_keys =>
        [
            user =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::User',
                key_columns => { userId => 'id' },
            },
        ],
        
        relationships =>
        [
            ban =>
            {
                type       => 'many to one',
                class      => 'Mojolicious::Plugin::MojoM::Model::User',
                column_map => { userId => id },
            },
        ],
    );

# Manager

package Mojolicious::Plugin::MojoM::Model::Ban::Manager;
use base 'Rose::DB::Object::Manager';

    sub object_class { 'Mojolicious::Plugin::MojoM::Model::Ban' }

    __PACKAGE__->make_manager_methods( 'ban' );

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
