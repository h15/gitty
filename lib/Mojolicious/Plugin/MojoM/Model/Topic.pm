package Mojolicious::Plugin::MojoM::Model::Topic;
use base 'Mojolicious::Plugin::MojoM::Base';

=head1 MySQL

create table `topic`
(
    `threadId`  int(11) unsigned not null,
    `title`     varchar(64) character set utf8 collate utf8_general_ci not null,
    `url`       varchar(64) character set ascii collate ascii_general_ci not null primary key,
    
    FOREIGN KEY (`threadId`)  REFERENCES `thread`(`id`)
);

=cut

    __PACKAGE__->meta->setup
    (
        table      => 'topic',
        
        columns    =>
        [
            threadId     => { type => 'integer', not_null => 1 },
            title        => { type => 'varchar', not_null => 1, length => 64 },
            url          => { type => 'varchar', not_null => 1, length => 64 },
        ],
        
        pk_columns => 'url',
        
        foreign_keys =>
        [
            thread =>
            {
                relationship_type   => 'one to one',
                class               => 'Mojolicious::Plugin::MojoM::Model::Thread',
                key_columns         => { threadId => 'id' },
            },
        ],
    );

# Manager

package Mojolicious::Plugin::MojoM::Model::Topic::Manager;
use base 'Rose::DB::Object::Manager';

    sub object_class { 'Mojolicious::Plugin::MojoM::Model::Topic' }

    __PACKAGE__->make_manager_methods( 'topic' );

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
