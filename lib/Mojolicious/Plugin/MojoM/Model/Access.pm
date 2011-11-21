package Mojolicious::Plugin::MojoM::Model::Access;
use base 'Mojolicious::Plugin::MojoM::Base';

=head1 MySQL

    create table `access`
    (
        `groupId`   int(11) unsigned not null,
        `dataTypeId`int(11) unsigned not null,
        `RWCD`      int(11) unsigned not null default 0,
        
        FOREIGN KEY (`groupId`)    REFERENCES `group`(`id`),
        FOREIGN KEY (`dataTypeId`) REFERENCES `dataType`(`id`)
    );

=cut

    __PACKAGE__->meta->setup
    (
        table      => 'access',
        
        columns    =>
        [
            groupId      => { type => 'integer', not_null => 1, length => 11  },
            dataTypeId   => { type => 'integer', not_null => 1, length => 11  },
            RWCD         => { type => 'integer', not_null => 1, length => 11, default => 0 },
        ],
        
        primary_key_columns => [ 'groupId', 'dataTypeId' ],

        foreign_keys =>
        [
            dataType =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::DataType',
                key_columns => { dataTypeId => 'id' },
            },

            group =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::Group',
                key_columns => { groupId => 'id' },
            },
        ],
    );

# Manager

package Mojolicious::Plugin::MojoM::Model::Access::Manager;
use base 'Rose::DB::Object::Manager';

    sub object_class { 'Mojolicious::Plugin::MojoM::Model::Access' }

    __PACKAGE__->make_manager_methods( 'access' );

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
