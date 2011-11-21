package Mojolicious::Plugin::MojoM::Model::User;
use base 'Mojolicious::Plugin::MojoM::Base';

=head1 MySQL

    create table `user`
    (
        `id`        int(11) unsigned not null auto_increment primary key,
        `mail`      varchar(255) character set utf8 collate utf8_general_ci not null,
        `name`      varchar(255) character set utf8 collate utf8_general_ci not null,
        `createAt`  int(11) not null,
        `modifyAt`  int(11) not null,
        `accessAt`  int(11) not null,
        `banId`     int(11) not null default 0,
        `banTime`   int(11) not null default 0,
        
        unique (`mail`),
        unique (`name`),
        
        FOREIGN KEY (`banId`)  REFERENCES `ban`(`id`)
    );

=cut

    __PACKAGE__->meta->setup(
        table      => 'user',
        
        columns    =>
        [
            id           => { type => 'serial' , not_null => 1 },
            mail         => { type => 'varchar', not_null => 1, length => 255 },
            name         => { type => 'varchar', not_null => 1, length => 255 },
            createAt     => { type => 'integer', not_null => 1, length => 11  },
            modifyAt     => { type => 'integer', not_null => 1, length => 11  },
            accessAt     => { type => 'integer', not_null => 1, length => 11  },
            banId        => { type => 'integer', not_null => 1, length => 11  },
            banTime      => { type => 'integer', not_null => 1, length => 11  },
        ],
        pk_columns => 'id',
        
        unique_key => 'mail',
        unique_key => 'name',
        
        foreign_keys =>
        [
            ban =>
            {
                class       => 'Mojolicious::Plugin::MojoM::Model::Ban',
                key_columns => { banId => 'id' },
            },
            
            mail =>
            {
                relationship_type   => 'one to one',
                class               => 'Mojolicious::Plugin::MojoM::Model::MailConfirm',
                key_columns         => { mail => 'mail' },
            },
        ],
        
        relationships =>
        [
            ban =>
            {
                type       => 'one to many',
                class      => 'Mojolicious::Plugin::MojoM::Model::Ban',
                column_map => { id => 'userId' },
            },
            
            thread =>
            {
                type       => 'one to many',
                class      => 'Mojolicious::Plugin::MojoM::Model::Thread',
                column_map => { id => 'userId' },
            },
            
            groups =>
            {
                type      => 'many to many',
                map_class => 'Mojolicious::Plugin::MojoM::Model::UserToGroup',
            }
        ],
    );

    sub isActive
        {
            my $self = shift;
            
            return 0 if 1 == $self->id;
            return 0 if 0 != $self->banId;
            
            return 1;
        }

    sub isAdmin
        {
            # 3rd - is default admin's group
            my $self = shift;
            
            if ( grep { $_ == 3 } split ' ', $self->groups ) {
                return 1;
            }
            return 0;
        }

    sub is_active
        {
            shift->isActive(@_);
        }

    sub is_admin
        {
            shift->isAdmin(@_);
        }

# Manager

package Mojolicious::Plugin::MojoM::Model::User::Manager;
use base 'Rose::DB::Object::Manager';

    sub object_class { 'Mojolicious::Plugin::MojoM::Model::User' }

    __PACKAGE__->make_manager_methods( 'user' );

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
