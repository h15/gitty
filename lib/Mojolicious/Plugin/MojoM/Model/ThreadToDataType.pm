package Mojolicious::Plugin::MojoM::Model::ThreadToDataType;
use base 'Mojolicious::Plugin::MojoM::Base';

=head1 MySQL

    create table `threadToDataType`
    (
        `threadId`  int(11) unsigned not null,
        `dataTypeId`int(11) unsigned not null,

        FOREIGN KEY (`threadId`)   REFERENCES `thread`(`id`),
        FOREIGN KEY (`dataTypeId`) REFERENCES `dataType`(`id`)
    );

=cut

    __PACKAGE__->meta->setup
    (
        table      => 'threadToDataType',
        
        columns    =>
        [
            threadId   => { type => 'integer', not_null => 1 },
            dataTypeId => { type => 'integer', not_null => 1 },
        ],
        
        primary_key_columns => [ 'threadId', 'dataTypeId' ],

        foreign_keys =>
        [
            thread =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::Thread',
                key_columns => { threadId => 'id' },
            },

            dataType =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::DataType',
                key_columns => { dataTypeId => 'id' },
            },
        ],
    );

# Manager

package Mojolicious::Plugin::MojoM::Model::ThreadToDataType::Manager;
use base 'Rose::DB::Object::Manager';

    sub object_class { 'Mojolicious::Plugin::MojoM::Model::ThreadToDataType' }

    __PACKAGE__->make_manager_methods( 'threadToDataType' );

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
