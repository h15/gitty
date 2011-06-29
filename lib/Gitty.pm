package Gitty;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
    my $app = shift;

    $app->plugin('i18n');
    $app->plugin('message');
    
    $app->plugin (
        'mojo_m' => {
            driver   => 'mysql',
            database => 'gitty',
            host     => 'localhost',
            username => 'gitty',
            password => 'gitty',
        }
    );
    
    $app->model('User')->init;
    $app->model('Article')->init (
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
    $app->model('Revision')->init (
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
    
    $app->plugin('captcha');
    
    $app->plugin( user => {
        cookies => 'some random string',    # random string for cookie salt;
        confirm => 7,                       # time to live of session in days;
        salt    => 'some random string',    # random string for db salt;
    });
    
    $app->plugin( gitosis => {
        git_home => '/home/h15/gitorepo/gitosis-admin/',
    });

    # Routes
    my $r = $app->routes;
       $r->namespace('Controller');
    
    my $w = $r->route('/wiki');
       $w->route( '/new'                      )->via('get' )->to('wiki#article_form'  )->name('wiki_article_form'  );
       $w->route( '/new'                      )->via('post')->to('wiki#article_create')->name('wiki_article_create');
       $w->route( '/:aid'    , aid => qr/\d+/ )->via('get' )->to('wiki#article_read'  )->name('wiki_article_read'  );
       $w->route( '/:aid'    , aid => qr/\d+/ )->via('post')->to('wiki#article_update')->name('wiki_article_update');
       $w->route( '/:aid/del', aid => qr/\d+/ )->via('post')->to('wiki#article_delete')->name('wiki_article_delete');
    
       my $rev = $w->route( '/:aid/:rid', aid => qr/\d+/, rid => qr/\d+/ );
          $rev->via('get' )->to('wiki#revision_read'  )->name('wiki_revision_read'  );
          $rev->via('post')->to('wiki#revision_update')->name('wiki_revision_update');
          $rev->route('/del')->via('post')->to('wiki#revision_delete')->name('wiki_revision_delete');
    
    $app->helper (
        is => sub {
            my ($self, $type, $val) = @_;

            if  ( $type eq 'mail' ) {
                return 1 if $val =~ m/^[a-z0-9_\-.]+\@[a-z0-9_\-.]+$/i;
            }
            return 0;
        }
    );
    
    $app->helper (
        IS => sub {
            my ($self, $type, $val) = @_;
            $self->error( "It's not $type!" ) unless $self->is($type, $val);
        }
    );
    
    $app->helper (
        render_datetime => sub {
            my ($self, $val) = @_;
            
            my ( $s, $mi, $h, $d, $mo, $y ) = localtime;
            my ( $sec, $min, $hour, $day, $mon, $year ) = map { $_ < 10 ? "0$_" : $_ } localtime($val);
            
            # Pretty time.
            my $str = (
                $year == $y ?
                    $mon == $mo ?
                        $day == $d ?
                            $hour == $h ?
                                $min == $mi ?
                                    $sec == $s ?
                                        $self->l('now')
                                    :   $self->l('a few seconds ago')
                                :   ago( min => $mi - $min, $self )
                            :   ago( hour => $h - $hour, $self )
                        :   "$hour:$min, $day.$mon"
                    :   "$hour:$min, $day.$mon"
                :   "$hour:$min, $day.$mon." . ($year + 1900)
            );
            
            $year += 1900;
            
            return new Mojo::ByteStream ( qq[<time datetime="$year-$mon-${day}T$hour:$min:${sec}Z">$str</time>] );
            
            sub ago {
                my ( $type, $val, $self ) = @_;
                my $a = $val % 10;
                
                # Different word for 1; 2-4; 0, 5-9 (in Russian it's true).
                $a = (
                    $a != 1 ?
                        $a > 4 ?
                            5
                        :   2
                    :   1
                );
                
                return $val ." ". $self->l("${type}s$a") ." ". $self->l('ago');
            }
        }
    );
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

