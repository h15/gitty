#!/usr/bin/env perl

use Test::More;
use Test::Mojo;

use utf8;

require "./script/gitty";

$ENV{MOJO_MODE} = "testing";

my  $t = Test::Mojo->new(app => 'Gitty');
    $t->get_ok('/')->status_is(404);

    # test git
    $t->get_ok('/git')->status_is(200)->content_like( qr'Repository list' );
    $t->get_ok('/git/new')->status_is(200)->content_like( qr'Create new repo' );
    $t->get_ok('/git/key')->status_is(200)->content_like( qr'Your public key' );

    # test mojom admin
    $t->get_ok ('/db')->status_is(200)->content_like( qr'Model&#39;s list' );
    $t->post_ok('/db')->status_is(404);

    $t->get_ok ('/db/1')->status_is(500);
    $t->post_ok('/db/1')->status_is(404);
    $t->get_ok ('/db/u')->status_is(500);
    $t->post_ok('/db/u')->status_is(404);

    $t->get_ok ('/db/u/new')->status_is(500);
    $t->post_ok('/db/u/new')->status_is(500);

    $t->get_ok ('/db/u/1')->status_is(500);
    $t->post_ok('/db/u/1')->status_is(500);
   
done_testing;

__END__

/db                     *       db                      (?-xism:^/db)
  +/                    GET     "mojo_m_list"           (?-xism:^)
  +/:id                 GET     "mojo_m_read"           (?-xism:^/((?-xism:[A-Za-z0-9\:]+)))
  +/:id/new             GET     "mojo_m_row_form"       (?-xism:^/((?-xism:[A-Za-z0-9\:]+))/new)
  +/:id/new             POST    "mojo_m_row_create"     (?-xism:^/((?-xism:[A-Za-z0-9\:]+))/new)
  +/:id/:rid            *       idrid                   (?-xism:^/((?-xism:[A-Za-z0-9\:]+))/((?-xism:\d+)))
    +/                  GET     "mojo_m_row_read"       (?-xism:^)
    +/                  POST    "mojo_m_row_update"     (?-xism:^)
    +/del               GET     "mojo_m_row_delete"     (?-xism:^/del)
/user                   *       user                    (?-xism:^/user)
  +/new                 POST    "users_create"          (?-xism:^/new)
  +/new                 GET     "users_form"            (?-xism:^/new)
  +/:id                 GET     "users_read"            (?-xism:^/((?-xism:\d+)))
  +/list/:id            *       "users_list"            (?-xism:^/list/((?-xism:\d*)))
  +/:id                 POST    "users_update"          (?-xism:^/((?-xism:\d+)))
  +/:id                 DELETE  "users_delete"          (?-xism:^/((?-xism:\d+)))
  +/login/mail/confirm  *       "auths_mail_confirm"    (?-xism:^/login/mail/confirm)
  +/login/mail          POST    "auths_mail_request"    (?-xism:^/login/mail)
  +/login/mail          GET     "auths_mail_form"       (?-xism:^/login/mail)
  +/login               POST    "auths_login"           (?-xism:^/login)
  +/login               GET     "auths_form"            (?-xism:^/login)
  +/logout              *       "auths_logout"          (?-xism:^/logout)
/git                    *       git                     (?-xism:^/git)
  +/                    GET     "gits_index"            (?-xism:^)
  +/new                 POST    "gits_create"           (?-xism:^/new)
  +/new                 GET     "gits_new"              (?-xism:^/new)
  +/key                 POST    "gits_key"              (?-xism:^/key)
  +/key                 GET     "gits_key_form"         (?-xism:^/key)
  +/server/key          POST    "gits_server_key"       (?-xism:^/server/key)
  +/server/key          GET     "gits_server_key_form"  (?-xism:^/server/key)
  +/:repo               POST    "gits_update"           (?-xism:^/([^\/\.]+))
  +/:repo               GET     "gits_read"             (?-xism:^/([^\/\.]+))
/wiki                   *       wiki                    (?-xism:^/wiki)
  +/new                 GET     "wiki_article_form"     (?-xism:^/new)
  +/new                 POST    "wiki_article_create"   (?-xism:^/new)
  +/:aid                GET     "wiki_article_read"     (?-xism:^/((?-xism:\d+)))
  +/:aid                POST    "wiki_article_update"   (?-xism:^/((?-xism:\d+)))
  +/:aid/del            POST    "wiki_article_delete"   (?-xism:^/((?-xism:\d+))/del)
  +/:aid/:rid           POST    "wiki_revision_update"  (?-xism:^/((?-xism:\d+))/((?-xism:\d+)))
    +/del               POST    "wiki_revision_delete"  (?-xism:^/del)

