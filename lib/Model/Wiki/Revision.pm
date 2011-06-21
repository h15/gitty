package Model::Wiki::Revision;

use base 'Model::Base';

__PACKAGE__->meta->setup(
    table      => 'revisions',
    columns    => [
        id          => { type => 'serial',  not_null => 1 },
        text        => { type => 'text',    not_null => 1 },
        article_id  => { type => 'integer', not_null => 1 },
        datetime    => { type => 'integer', not_null => 1 },
        user        => { type => 'integer', not_null => 1 },
    ],
    pk_columns => 'id',
    foreign_keys => [
        article     => {
            class       => 'Model::Wiki::Article',
            key_columns => { article_id => 'id' },
        },
    ],
);

1;

__END__

=head1 MySQL

    CREATE TABLE `gitty`.`revisions` (
        `id` INT( 11 ) UNSIGNED NOT NULL AUTO_INCREMENT ,
        `article_id` INT( 11 ) UNSIGNED NOT NULL ,
        `text` TEXT CHARACTER SET utf8 COLLATE utf8_bin NOT NULL ,
        `datetime` INT( 11 ) UNSIGNED NOT NULL ,
        `user` INT( 11 ) UNSIGNED NOT NULL ,
        PRIMARY KEY ( `id` ) ,
        FOREIGN KEY ( `article_id` ) REFERENCES articles ( `id` ),
        INDEX ( `id` )
    ) ENGINE = MYISAM ;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
