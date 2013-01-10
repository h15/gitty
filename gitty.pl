#!/usr/bin/perl

use DBI;
use utf8;
use strict;
use warnings;
use feature ':5.10';
use Mojolicious::Lite;
use Digest::MD5 qw(md5_hex);


our $VERSION = '1.prealpha';

#------------------------------------------------------------------- Config --#

my $FILE = 'gitty.db';
my $SOLT = 'gitty-global-solt';
my $GITOLITE_DIR = './gitolite-admin';
my $SECRET_KEY = 'ailous6queem4ie0Maifo9awee0oiphi';


#------------------------------------------------------------ Init database --#

our $dbh = DBI->connect("dbi:SQLite:dbname=$FILE", '', '', { RaiseError => 1 })
            or die $DBI::errstr;


#-------------------------------------------------------------- Controllers --#

get '/' => sub {
  my $self = shift;
  
  # INSTALL database if doesn't exist.
  unless (-r $FILE) {
    $self->redirect_to('/install')
  }
  
  return $self->render('index');
};


get '/install' => sub {
  my $self = shift;
  
  Model->new->raw(q{
    CREATE TABLE user (
      id INTEGER PRIMARY KEY,
      name VARCHAR(32) UNIQUE,
      mail VARCHAR(32) UNIQUE,
      password VARCHAR(32),
      regdate INTEGER,
      key_count INTEGER,
      info TEXT
    );
  });
  
  Model->new->raw(q{
    INSERT INTO user VALUES(1, 'admin', 'admin@gitty',
      '505d1c27e7702820f632a7564194c714', 0, 0, 'Gitty Admin');
  });
  
  Model->new->raw(q{
    CREATE TABLE key (
      id INTEGER PRIMARY KEY,
      user_id INTEGER,
      name VARCHAR(32),
      key TEXT,
      FOREIGN KEY(user_id) REFERENCES user(id)
    );
  });
  
  return $self->render('install');
};


get '/user/login' => sub {
  my $self = shift;
  $self->stash({error => ''});
  $self->render('user/login');
};


post '/user/login' => sub {
  my $self = shift;
  my $user = $self->param('user');
  my $pass = $self->param('pass');
  $user = Model->new('user')->read('name', $user);
  
  if ($user) {
    if ($user->{password} eq md5_hex("$SOLT-".$user->{regdate}."-$pass")) {
      $self->session(id => $user->{id}, name => $user->{name},
                     mail => $user->{mail}, regdate => $user->{regdate},
                     key_count => $user->{key_count});
      
      $user->{id} == 1? $self->redirect_to('/admin') :
                        $self->redirect_to('/user/home');
    } else {
      $self->stash({error => q/Wrong password!/});
      $self->render('user/login');
    }
  } else {
    $self->stash({error => q/Can't find user!/});
    $self->render('user/login');
  }
};


get '/admin' => sub {
  my $self = shift;
  $self->render('admin/index');
};


get '/admin/users' => sub {
  my $self = shift;
  my @users = Model->new('user')->list;
  $self->stash({users => \@users})->render('admin/users');
};


post '/admin/users' => sub {
  my $self = shift;
  my $time = time;
  my $user = $self->param('user');
  my $pass = $self->param('pass');
  
  Model->new('user')->create({
    name => $self->param('user'),
    password => md5_hex("$SOLT-$time-$pass"),
    regdate => $time,
    });
  
  $self->redirect_to('/admin/users');
};


get '/user/home' => sub {
  my $self = shift;
  my $user_id = $self->session('id');
  my $user = Model->new('user')->read(id => $user_id);
  $self->stash({user => $user})->render('user/home');
};


post '/user/home' => sub {
  my $self = shift;
  my $pass = $self->param('password');
  my $time = $self->session('regdate');
  
  my $data = {
    name => $self->param('name'),
    mail => $self->param('mail'),
    info => $self->param('info'),
    };
  
  $data = { %$data, password => md5_hex("$SOLT-$time-$pass") } if $pass;
  Model->new('user')->update($data, { id => $self->session('id') });
  $self->redirect_to('/user/home');
};


get '/user/keys' => sub {
  my $self = shift;
  my @keys = Model->new('key')->list({user_id => $self->session('id')});
  $self->stash({keys => \@keys})->render('user/keys');
};


post '/user/keys' => sub {
  my $self = shift;
  my $name = $self->param('name');
  my $key  = $self->param('key');
  
  Model->new('key')->create({
    user_id => $self->session('id'),
    name => $name,
    key => $key
    });
  
  $self->redirect_to('/user/keys');
};


app->start('daemon');


#--------------------------------------------------------- Useful functions --#

sub parse_gitolite_config {
  open CONFIG, "$GITOLITE_DIR/conf/gitolite.conf"
    or die "Can't find gitolite config file.";
  
  my $expr = qr/[a-z0-9_]+/;
  my $list = qr/[a-z0-9_@]+/;
  my %groups;
  my %repos;
  my $cur_repo = '';
  
  while (my $line = <CONFIG>) {
    given($line) {
      # group definition
      when(/^\s*@($expr)\s*=\s*($expr(?:\s+$expr)+)\s+$/i) {
        %groups = ( %groups, $1 => [split/ /, $2] );
      }
      # repo definition
      when(/^\s*repo\s+($expr)\s+$/) {
        $cur_repo = $1;
      }
      # end of repo || just empty line
      when(/^\s*$/) {
        $cur_repo = '';
      }
      # repo users
      when(/^\s*([RW+CD]+)\s*=\s*($list)\s*$/) {
        %repos = (%repos, $cur_repo => { $1 => [split/ /, $2] });
      }
    }
  }
  
  return(\%groups, \%repos);
}


#-------------------------------------------------------------------- Model --#

package Model;

sub new {
  my($class, $table_name) = @_;
  return bless({table => $table_name}, $class);
}

sub create {
  my $self = shift;
  my $data = shift;
  
  while(my($k, $v) = each %$data) {
      $data->{$k} = $main::dbh->quote($v);
  }
  
  my $t = $self->{table};
  my $k = join '`,`', keys %$data;
  my $v = join ",", values %$data;
  
  $main::dbh->do("INSERT INTO `$t`(`$k`) VALUES($v)");
  my $sth = $main::dbh->prepare("SELECT last_insert_rowid()");
     $sth->execute();
  my $row = $sth->fetchrow_hashref();
  return $row->{'last_insert_rowid()'};
}

sub read {
  my($self, $w, $f) = @_;
  ($w, $f) = ( {$w, $f}, undef ) if ref $w ne 'HASH';
  my($order) = keys %$w;
  return [ $self->list($w, $f, $order, undef, 0, 1) ]->[0];
}

sub update {
  my($self, $data, $where) = @_;
  my @where = $self->_prepare($where);
  my @data = $self->_prepare($data);
  my $t = $self->{table};
  my $w = join ' and ', @where;
  my $d = join ',', @data;
  $main::dbh->do("UPDATE `$t` SET $d WHERE $w");
}

sub delete {
  my($self, $where) = @_;
  my @where = $self->_prepare($where);
  my $t = $self->{table};
  my $w = join ' and ', @where;
  $main::dbh->do("DELETE FROM `$t` WHERE $w");
}

sub list {
  my($self, $where, $fields, $order, $rule, $offset, $limit) = @_;
  @$fields = map { "`$_`" } @$fields if $fields;
  # defaults
  $fields ||= ['*'];
  $order  ||= 'id';
  $rule   ||= 'DESC';
  $offset ||= 0;
  $limit  ||= 20;
  # prepare
  my $w = ( $where ? join ' and ', $self->_prepare($where) : '1=1' );
  my $t = $self->{table};
  my $f = join ',', @$fields;
  my $q = "SELECT $f FROM `$t` WHERE $w
            ORDER BY $order $rule LIMIT $offset, $limit";
  # run
  my $sth = $main::dbh->prepare($q);
     $sth->execute();
  my @result;
  my $row;
  push @result, $row while $row = $sth->fetchrow_hashref();
  return @result;
}

sub count {
  my($self, $where) = @_;
  # Prepare
  my $w = ( $where ? join ' and ', $self->_prepare($where) : '1=1' );
  my $t = $self->{table};
  my $q = "SELECT COUNT(*) FROM `$t` WHERE $w";
  # Run
  my $sth = $main::dbh->prepare($q);
     $sth->execute();
  my $row = $sth->fetchrow_hashref();
  return $row->{'COUNT(*)'};
}

sub raw {
  my($self, $query) = @_;
  my $sth = $main::dbh->prepare($query);
     $sth->execute();
  my @result;
  my $row;
  push @result, $row while $row = $sth->fetchrow_hashref();
  return @result;
}

sub _prepare {
  my($self, $data) = @_;
  my @data;
  
  while(my($k, $v) = each %$data) {
    push @data, sprintf "`%s`=%s", $k, $main::dbh->quote($v);
  }
  
  return @data;
}


package main;
__DATA__
@@ layouts/default.html.ep
<!doctype html>
<html>
<head>
<title><% title %></title>
<style>
body{ font-family: mono; }
</style>
</head>
  <body>
    <div>
      <a href="/user/home">Home</a>
      <a href="/user/login">Login</a>
    </div>
    % if (session('id') == 1) {
      <div>
        <a href="/admin/users">Users</a>
      </div>
    % }
  <%= content %>
  </body>
</html>


@@ install.html.ep
% layout 'default', title => 'Installed';
<h1>Database installed</h1>


@@ index.html.ep
% layout 'default';
<h1></h1>


@@ user/login.html.ep
% layout 'default', title => 'Login';
<div class="error"><%= $error %></div>
<form action="/user/login" method="POST">
  <input name="user"><br>
  <input name="pass" type="password"><br>
  <input type="submit" value="Login">
</form>


@@ admin/index.html.ep
% layout 'default', title => 'Admin panel';


@@ admin/users.html.ep
% layout 'default', title => 'Admin panel → Users';
<form action="/admin/users" method="POST">
  <input name="user">
  <input name="pass" type="password">
  <input type="submit" value="Create">
</form>
<ul>
% for my $u (@$users) {
  <li><%= $u->{name} %>(<%= $u->{mail} %>)</li>
% }
</ul>


@@ user/home.html.ep
% layout 'default', title => 'User home';
<form action="/user/home" method="POST">
  <table>
    <tr>
      <td>Name</td>
      <td><input name="name" value='<%= $user->{name} %>'></td>
    </tr>
    <tr>
      <td>E-mail</td>
      <td><input name="mail" value='<%= $user->{mail} %>'></td>
    </tr>
    <tr>
      <td>Info</td>
      <td><textarea name="info"><%= $user->{info} %></textarea></td>
    </tr>
    <tr>
      <td>Password *</td>
      <td><input name="password" type="password"></td>
    </tr>
    <tr>
      <td colspan=2><input type="submit" value="Change"></td>
    </tr>
  </table>
</form>


@@ user/keys.html.ep
% layout 'default', title => 'Public keys';
<form action="/user/keys" method="POST">
  <table>
    <tr>
      <td>Name</td>
      <td><input name="name"></td>
    </tr>
    <tr>
      <td>Key</td>
      <td><textarea name="key"></textarea></td>
    </tr>
    <tr>
      <td colspan=2><input type="submit" value="Add"></td>
    </tr>
  </table>
</form>
<ul>
% for my $k (@$keys) {
  <li><%= $k->{name} %> (<%= substr($k->{key}, 0, 20) %> ...
                         <%= substr($k->{key}, -20) %>)</li>
% }
</ul>

__END__

=pod

=head1 How to install

Admin access - admin:nimda

=head2 Prepare git user

Install soft. Run as root.

  aptitude install openssh-server git-core

  adduser --system --shell /bin/sh --gecos 'git version control' --group \
          --disabled-password --home /home/git git

Create ssh key for git.

  sudo -u git ssh-keygen

Allow ssh support for git. Edit manually file C</etc/ssh/sshd_config>. Add user
C<git> into line "AllowUsers".

  /etc/init.d/ssh restart

=head2 Install Gitolite

Run as root.

  aptitude install gitolite

Run as git.

  gl-setup ~/root.pub

Get admin repo (run as git-admin user).

  git clone git@server:gitolite-admin

=head2 Install Perl modules

  sudo cpan Mojolicious DBI DBD::SQLite

=cut
