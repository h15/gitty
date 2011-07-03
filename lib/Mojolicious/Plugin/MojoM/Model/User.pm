package Mojolicious::Plugin::MojoM::Model::User;

use base 'Mojolicious::Plugin::MojoM::Base';

__PACKAGE__->meta->setup(
    table      => 'users',
    columns    => [
        id           => { type => 'serial' , not_null => 1 },
        name         => { type => 'varchar', length => 32 },
        ban_reason   => { type => 'integer', not_null => 1, default => 0 },
        ban_time     => { type => 'integer', not_null => 1, default => 0 },
        groups       => { type => 'text'   , not_null => 1 },
        regdate      => { type => 'integer', not_null => 1 },
        mail         => { type => 'varchar', not_null => 1, length => 64 },
        password     => { type => 'varchar', not_null => 1, default => 0, length => 32 },
        confirm_key  => { type => 'varchar', not_null => 1, length => 32 },
        confirm_time => { type => 'integer', not_null => 1, length => 32 },
    ],
    pk_columns => 'id',
    unique_key => 'mail',
    unique_key => 'name',
);

sub is_active {
    my $self = shift;
    
    return 0 if 1 == $self->id;
    return 0 if 0 != $self->ban_reason;
    
    return 1;
};

sub is_admin {
    # 3rd - is default admin's group
    my $self = shift;
    
    if ( grep { $_ == 3 } split ' ', $self->groups ) {
        return 1;
    }
    return 0;
}

# Manager

package Mojolicious::Plugin::MojoM::Model::User::Manager;
use base 'Rose::DB::Object::Manager';

sub object_class { 'Mojolicious::Plugin::MojoM::Model::User' }

__PACKAGE__->make_manager_methods( 'user' );

1;

__END__

=head1 MySQL

    CREATE TABLE IF NOT EXISTS `users` (
      `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
      `groups` tinytext NOT NULL,
      `name` varchar(32) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
      `mail` varchar(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `regdate` int(11) unsigned NOT NULL,
      `password` varchar(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '0',
      `ban_reason` int(2) unsigned NOT NULL DEFAULT '0',
      `ban_time` int(11) unsigned NOT NULL DEFAULT '0',
      `confirm_key` varchar(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
      `confirm_time` int(11) unsigned NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `mail` (`mail`),
      KEY `id` (`id`)
    ) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=2 ;

    INSERT INTO `users` (`id`, `groups`, `name`, `mail`, `regdate`, `password`, `ban_reason`, `ban_time`, `confirm_key`, `confirm_time`) VALUES
    (1, '', 'anonymous', 'anonymous@lorcode.org', 0, '0', 0, 0, '', 0);

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
