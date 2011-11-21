package Mojolicious::Plugin::MojoM::Model::Thread;
use base 'Mojolicious::Plugin::MojoM::Base';

=head1 MySQL

    create table `thread`
    (
        `id`        int(11) unsigned not null auto_increment primary key,
        `userId`    int(11) unsigned not null default 0,
        `createAt`  int(11) unsigned not null,
        `modifyAt`  int(11) unsigned not null,
        `parentId`  int(11) unsigned not null,
        `topicId`   int(11) unsigned not null,
        `textId`    int(11) unsigned not null,
        
        FOREIGN KEY (`userId`)   REFERENCES `user`(`id`),
        FOREIGN KEY (`parentId`) REFERENCES `thread`(`id`),
        FOREIGN KEY (`topicId`)  REFERENCES `topic`(`id`),
        FOREIGN KEY (`textId`)   REFERENCES `text`(`id`)
    );

=cut

    __PACKAGE__->meta->setup(
        table      => 'thread',
        
        columns    =>
        [
            id           => { type => 'serial' , not_null => 1 },
            userId       => { type => 'integer', not_null => 1, length => 11, default => 0 },
            createAt     => { type => 'integer', not_null => 1, length => 11  },
            modifyAt     => { type => 'integer', not_null => 1, length => 11  },
            parentId     => { type => 'integer', not_null => 1, length => 11  },
            topicId      => { type => 'integer', not_null => 1, length => 11  },
            textId       => { type => 'integer', not_null => 1, length => 11  },
        ],
        
        pk_columns => 'id',
        
        foreign_keys =>
        [
            user =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::User',
                key_columns => { userId => 'id' },
            },
            
            text =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::Text',
                key_columns => { textId => 'id' },
            },
        ],
        
        relationships =>
        [
            user =>
            {
                type       => 'many to one',
                class      => 'Mojolicious::Plugin::MojoM::Model::User',
                column_map => { userId => 'id' },
            },
            
            parent =>
            {
                type       => 'many to one',
                class      => 'Mojolicious::Plugin::MojoM::Model::Thread',
                column_map => { parentId => 'id' },
            },
            
            topic =>
            {
                type       => 'many to one',
                class      => 'Mojolicious::Plugin::MojoM::Model::Topic',
                column_map => { topicId => 'id' },
            }
        ],
    );

# Manager

package Mojolicious::Plugin::MojoM::Model::Thread::Manager;
use base 'Rose::DB::Object::Manager';

    sub object_class { 'Mojolicious::Plugin::MojoM::Model::Thread' }

    __PACKAGE__->make_manager_methods( 'thread' );

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
