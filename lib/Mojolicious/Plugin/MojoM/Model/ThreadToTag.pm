package Mojolicious::Plugin::MojoM::Model::ThreadToTag;
use base 'Mojolicious::Plugin::MojoM::Base';

=head1 MySQL

    create table `threadToTag`
    (
        `threadId`  int(11) unsigned not null,
        `tagId`     int(11) unsigned not null,
        
        FOREIGN KEY (`threadId`) REFERENCES `thread`(`id`),
        FOREIGN KEY (`tagId`)    REFERENCES `tag`(`id`)
    );

=cut

    __PACKAGE__->meta->setup
    (
        table      => 'threadToTag',
        
        columns    =>
        [
            threadId => { type => 'integer', not_null => 1 },
            tagId    => { type => 'integer', not_null => 1 },
        ],
        
        primary_key_columns => [ 'threadId', 'tagId' ],

        foreign_keys =>
        [
            thread =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::Thread',
                key_columns => { threadId => 'id' },
            },

            tag =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::Tag',
                key_columns => { tagId => 'id' },
            },
        ],
    );

# Manager

package Mojolicious::Plugin::MojoM::Model::ThreadToTag::Manager;
use base 'Rose::DB::Object::Manager';

    sub object_class { 'Mojolicious::Plugin::MojoM::Model::ThreadToTag' }

    __PACKAGE__->make_manager_methods( 'threadToTag' );

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
