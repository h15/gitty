package Mojolicious::Plugin::MojoM::Model::MailConfirm;
use base 'Mojolicious::Plugin::MojoM::Base';

=head1 MySQL

    create table `mailConfirm`
    (
        `expair`    int(11) unsigned not null default 0,
        `mail`      varchar(255) character set utf8 collate utf8_general_ci not null primary key,
        `secret`    varchar(32) character set ascii collate ascii_general_ci not null,
        `attempts`  int(1) unsigned not null default 0
    );

=cut

    __PACKAGE__->meta->setup
    (
        table      => 'mailConfirm',
        
        columns    =>
        [
            expair       => { type => 'integer', not_null => 1, length => 11  },
            mail         => { type => 'varchar', not_null => 1, length => 255 },
            secret       => { type => 'varchar', not_null => 1, length => 32  },
            attempts     => { type => 'integer', not_null => 1, length => 1   },
        ],
        
        pk_columns => 'mail',
        
        foreign_keys =>
        [
            mail =>
            {
                relationship_type   => 'one to one',
                class               => 'Mojolicious::Plugin::MojoM::Model::User',
                key_columns         => { mail => 'mail' },
            },
        ],
    );

# Manager

package Mojolicious::Plugin::MojoM::Model::MailConfirm::Manager;
use base 'Rose::DB::Object::Manager';

    sub object_class { 'Mojolicious::Plugin::MojoM::Model::MailConfirm' }

    __PACKAGE__->make_manager_methods( 'mailConfirm' );

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
