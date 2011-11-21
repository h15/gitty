package Mojolicious::Plugin::MojoM::Model::UserToGroup;
use base 'Mojolicious::Plugin::MojoM::Base';

=head1 MySQL

    create table `userToGroup`
    (
        `userId`    int(11) unsigned not null,
        `groupId`   int(11) unsigned not null,
        
        FOREIGN KEY (`userId`)  REFERENCES `user`(`id`),
        FOREIGN KEY (`groupId`) REFERENCES `group`(`id`)
    );

=cut

    __PACKAGE__->meta->setup
    (
        table      => 'userToGroup',
        
        columns    =>
        [
            userId  => { type => 'integer', not_null => 1 },
            groupId => { type => 'integer', not_null => 1 },
        ],
        
        primary_key_columns => [ 'userId', 'groupId' ],

        foreign_keys =>
        [
            user =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::User',
                key_columns => { userId => 'id' },
            },

            group =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::Group',
                key_columns => { groupId => 'id' },
            },
        ],
    );

# Manager

package Mojolicious::Plugin::MojoM::Model::UserToGroup::Manager;
use base 'Rose::DB::Object::Manager';

    sub object_class { 'Mojolicious::Plugin::MojoM::Model::UserToGroup' }

    __PACKAGE__->make_manager_methods( 'userToGroup' );

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
