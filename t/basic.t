#!/usr/bin/env perl
use Mojo::Base -strict;

use Test::More tests => 4;
use Test::Mojo;

use_ok 'Gitty';

my $t = Test::Mojo->new('Gitty');
$t->get_ok('/welcome')->status_is(200)->content_like(qr/Mojolicious/i);
