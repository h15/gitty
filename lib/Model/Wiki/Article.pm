package Model::Wiki::Article;

use base 'Model::Base';

__PACKAGE__->meta->setup(
    table      => 'articles',
    columns    => [
        id          => { type => 'serial' , not_null => 1 },
        title       => { type => 'varchar', length => 255, not_null => 1 },
        revision_id => { type => 'integer' },
        status      => { type => 'integer' },
    ],
    pk_columns => 'id',
    unique_key => 'title',
    foreign_keys => [
        revision    => {
            class       => 'Model::Wiki::Revision',
            key_columns => { revision_id => 'id' },
        },
    ],
);

1;

__END__

=head1 MySQL

    CREATE TABLE `gitty`.`articles` (
        `id` INT( 11 ) UNSIGNED NOT NULL AUTO_INCREMENT ,
        `title` VARCHAR( 255 ) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL ,
        `revision_id` INT( 11 ) UNSIGNED NOT NULL ,
        `status` INT( 2 ) UNSIGNED NOT NULL ,
        PRIMARY KEY ( `id` ) ,
        FOREIGN KEY ( `revision_id` ) REFERENCES revisions ( `id` ),
        INDEX ( `id` ) ,
        UNIQUE (
            `title`
        )
    ) ENGINE = MYISAM;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
