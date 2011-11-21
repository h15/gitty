package Mojolicious::Plugin::MojoM::Model::Tag;
use base 'Mojolicious::Plugin::MojoM::Base';

=head1 MySQL

    create table `tag`
    (
        `id`        int(11) unsigned not null auto_increment primary key,
        `url`       varchar(64) character set ascii collate ascii_general_ci not null,
        `name`      varchar(64) character set utf8 collate utf8_general_ci not null,
        
        unique(`url`)
    );

=cut

    __PACKAGE__->meta->setup
    (
        table      => 'tag',
        
        columns    =>
        [
            id           => { type => 'serial' , not_null => 1 },
            url          => { type => 'varchar', not_null => 1, length => 64 },
            name         => { type => 'varchar', not_null => 1, length => 64 },
        ],
        
        pk_columns => 'id',
        
        unique_key => 'url',
        
        relationships =>
        [
            threads =>
            {
                type      => 'many to many',
                map_class => 'Mojolicious::Plugin::MojoM::Model::ThreadToTag',
            }
        ],
    );

# Manager

package Mojolicious::Plugin::MojoM::Model::Tag::Manager;
use base 'Rose::DB::Object::Manager';

    sub object_class { 'Mojolicious::Plugin::MojoM::Model::Tag' }

    __PACKAGE__->make_manager_methods( 'tag' );

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
