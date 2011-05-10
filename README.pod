
=head1 NAME

Gitty - web application for git (gitosis).

=head1 OVERVIEW

Gitty is a small web app, based on joke code base. It uses Mojolicious Perl framework.
Now it can makes and use Users, tunes gitosis config, adds public keys.

=head1 INSTALL

=head2 Clone it from repository

    git clone git@github.com:h15/gitty.git

=head2 Install Perl modules

    curl -L cpanmin.us | perl - Mojolicious DBIx::Simple SQL::Abstract MIME::Lite

=head2 Create data base and tables.

Users' accounts need some data for save.

=head3 For MySQL

    CREATE TABLE `gitty`.`gitty__users` (
        `id` INT( 11 ) UNSIGNED NOT NULL AUTO_INCREMENT ,
        `groups` TINYTEXT NOT NULL ,
        `name` VARCHAR( 32 ) CHARACTER SET utf8 COLLATE utf8_bin NULL ,
        `mail` VARCHAR( 64 ) CHARACTER SET ascii COLLATE ascii_bin NOT NULL ,
        `regdate` INT( 11 ) UNSIGNED NOT NULL ,
        `password` VARCHAR( 32 ) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '0',
        `ban_reason` INT( 2 ) UNSIGNED NOT NULL DEFAULT '0',
        `ban_time` INT( 11 ) UNSIGNED NOT NULL DEFAULT '0',
        `confirm_key` VARCHAR( 32 ) CHARACTER SET ascii COLLATE ascii_bin NOT NULL ,
        `confirm_time` INT( 11 ) UNSIGNED NOT NULL ,
        PRIMARY KEY ( `id` ) ,
        INDEX ( `id` ) ,
        UNIQUE (
            `name` ,
            `mail`
        )
    ) ENGINE = MYISAM ;

    INSERT INTO `gitty__users` (`id`, `groups`, `name`, `mail`, `regdate`, `password`, `ban_reason`, `ban_time`, `confirm_key`, `confirm_time`) VALUES(1, '', 'anonymous', 'anonymous@lorcode.org', 0, '0', 0, 0, '', 0);

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

