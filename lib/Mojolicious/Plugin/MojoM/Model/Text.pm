package Mojolicious::Plugin::MojoM::Model::Text;
use base 'Mojolicious::Plugin::MojoM::Base';

=head1 MySQL

    create table `text`
    (
        `id`        int(11) unsigned not null auto_increment primary key,
        `threadId`  int(11) unsigned not null,
        `text`      varchar(60000) character set utf8 collate utf8_general_ci not null,
        
        FOREIGN KEY (`threadId`)  REFERENCES `thread`(`id`)
    );

=cut

    __PACKAGE__->meta->setup
    (
        table      => 'text',
        
        columns    =>
        [
            id           => { type => 'serial' , not_null => 1 },
            threadId     => { type => 'integer', not_null => 1 },
            text         => { type => 'varchar', not_null => 1, length => 60_000 },
        ],
        
        pk_columns => 'id',
        
        foreign_keys =>
        [
            thread =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::Thread',
                key_columns => { threadId => 'id' },
            },
        ],
        
        relationships =>
        [
            threads =>
            {
                type      => 'many to one',
                map_class => 'Mojolicious::Plugin::MojoM::Model::Thread',
            }
        ],
    );

# Manager

package Mojolicious::Plugin::MojoM::Model::Text::Manager;
use base 'Rose::DB::Object::Manager';

    sub object_class { 'Mojolicious::Plugin::MojoM::Model::Text' }

    __PACKAGE__->make_manager_methods( 'text' );

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
