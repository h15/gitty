#!/usr/bin/perl

use DBI;
use utf8;
use strict;
use warnings;
use feature ':5.10';
use Mojolicious::Lite;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;


our $VERSION = '1.prealpha';


#------------------------------------------------------------ Init database --#

our $dbh = DBI->connect("dbi:SQLite:dbname=./gitty.db",
                        '', '', { RaiseError => 1 })
            or die $DBI::errstr;


#-------------------------------------------------------------- Controllers --#

get '/' => sub {
  my $self = shift;
  # INSTALL database if doesn't exist.
  eval{ Model->new('config')->read(name => 'salt') };
  $self->redirect_to('/install') if $@;
  return $self->render('index');
};


get '/install' => sub {
  my $self = shift;
  my $error = $self->param('error') || '';
  $self->stash({salt => md5_hex(rand), secret_key => md5_hex(rand),
                error => $error})->render('install');
};


post '/install' => sub {
  my $self = shift;
  my $salt = $self->param('salt');
  my $secret_key = $self->param('secret_key');
  my $gl_dir = $self->param('gl_dir');
  my $time = time;
  my $pass = $self->param('pass');
  my $pass2 = $self->param('pass2');
  my $admin_password_hash = md5_hex("$salt-$time-$pass");
  
  return $self->redirect_to('/install?error=bad_params') if $salt =~ /'/;
  return $self->redirect_to('/install?error=bad_params') if $secret_key =~ /'/;
  return $self->redirect_to('/install?error=bad_params') if $gl_dir =~ /'/;
  return $self->redirect_to('/install?error=bad_params') if $pass ne $pass2;
  
  Model->new->raw(q{
    CREATE TABLE config (
      name VARCHAR(32) PRIMARY KEY,
      value TEXT
    );
  });
  Model->new->raw(qq{INSERT INTO config VALUES('salt'      , '$salt');});
  Model->new->raw(qq{INSERT INTO config VALUES('secret_key', '$secret_key');});
  Model->new->raw(qq{INSERT INTO config VALUES('gl_dir'    , '$gl_dir');});
  
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
  Model->new->raw(qq{
    INSERT INTO user VALUES(1, 'admin', 'admin\@gitty',
      '$admin_password_hash', 0, 0, 'Gitty Admin');
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
  
  Model->new->raw(q{
    CREATE TABLE 'group' (
      name VARCHAR(32) PRIMARY KEY,
      list TEXT
    );
  });
  
  Model->new->raw(q{
    CREATE TABLE repo (
      name VARCHAR(32) PRIMARY KEY,
      list TEXT
    );
  });
  
  $self->session(id => 1, name => 'admin', mail => 'admin@gitty',
                 regdate => $time, key_count => 0);
  return $self->redirect_to('/admin');
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
    my $salt = Model->new('config')->read(name => 'salt')->{value};
    if ($user->{password} eq md5_hex("$salt-".$user->{regdate}."-$pass")) {
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
  my $salt = Model->new('config')->read(name => 'salt')->{value};
  
  Model->new('user')->create({
    name => $self->param('user'),
    password => md5_hex("$salt-$time-$pass"),
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
  my $salt = Model->new('config')->read(name => 'salt')->{value};
  
  my $data = {
    name => $self->param('name'),
    mail => $self->param('mail'),
    info => $self->param('info'),
    };
  
  $data = { %$data, password => md5_hex("$salt-$time-$pass") } if $pass;
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


get '/admin/repos' => sub {
  my $self = shift;
  my @groups = Model->new('group')->list;
  my @repos = Model->new('repo')->list;
  $self->stash({repos => \@repos, groups => \@groups})->render('admin/repos');
};


post '/admin/repos' => sub {
  my $self = shift;
  my $name = $self->param('name');
  my $desc = $self->param('desc');
  my $list = $self->param('list'); # user list
  
  Model->new('repo')->create({
    name => $name,
    desc => $desc,
    list => $list
    });
  
  $self->redirect_to('/admin/repos');
};


get '/admin/groups' => sub {
  my $self = shift;
  my @groups = Model->new('group')->list;
  $self->stash({groups => \@groups})->render('admin/groups');
};


post '/admin/groups' => sub {
  my $self = shift;
  my $name = $self->param('name');
  my $desc = $self->param('desc');
  my $list = $self->param('list');
  
  Model->new('group')->create({
    name => $name,
    desc => $desc,
    list => $list
    });
  
  $self->redirect_to('/admin/groups');
};


get '/admin/config/startup' => sub {
  my $self = shift;
  my ($groups, $repos) = parse_gitolite_config();
  $self->stash({groups => $groups, repos => $repos})->render('admin/startup');
};


# Load startup-config.
post '/admin/config/startup' => sub {
  my $self = shift;
  my ($groups, $repos) = parse_gitolite_config();
  save_gitolite_config_to_db($groups, $repos);
  $self->redirect_to('/admin/config/running');
};


get '/admin/config/gitty' => sub {
  my $self = shift;
  my $secret_key = Model->new('config')->read({name => 'secret_key'})->{value};
  my $gl_dir = Model->new('config')->read({name => 'gl_dir'})->{value};
  $self->stash({secret_key => $secret_key, gl_dir => $gl_dir})
    ->render('admin/gitty');
};


post '/admin/config/gitty' => sub {
  my $self = shift;
  my $secret_key = $self->param('secret_key');
  my $gl_dir = $self->param('gl_dir');
  Model->new('config')->update({value => $secret_key}, {name => 'secret_key'});
  Model->new('config')->update({value => $gl_dir}, {name => 'gl_dir'});
  $self->redirect_to('/admin/config/gitty');
};


get '/admin/config/running' => sub {
  my $self = shift;
  my ($groups, $repos) = get_gitolite_config_from_db();
  my $text = generate_gitolite_config($groups, $repos);
  
  $self->stash({groups => $groups, repos => $repos, conf => $text})
    ->render('admin/running');
};


# Save running-config to startup-config.
post '/admin/config/running/to/startup' => sub {
  my $self = shift;
  my $gl_dir = Model->new('config')->read(name => 'gl_dir')->{value};
  my ($groups, $repos) = get_gitolite_config_from_db();
  my $text = generate_gitolite_config($groups, $repos);
  
  open CONFIG, ">$gl_dir/conf/gitolite.conf"
    or die "Can't find gitolite config file.";
  print CONFIG $text;
  close CONFIG;
  
  $self->redirect_to('/admin/config/running');
};


post '/admin/config/running' => sub {
  my $self = shift;
  my $conf = $self->param('conf');
  my ($groups, $repos) = parse_gitolite_config($conf);
  save_gitolite_config_to_db($groups, $repos);
  $self->redirect_to('/admin/config/running');
};

app->start('daemon');


#--------------------------------------------------------- Useful functions --#

sub parse_gitolite_config {
  my @CONFIG;
  
  if (@_) {
    @CONFIG = split /\n/, shift;
  }
  else {
    my $gl_dir = Model->new('config')->read(name => 'gl_dir')->{value};
    open CONFIG, "$gl_dir/conf/gitolite.conf"
      or die "Can't find gitolite config file.";
    @CONFIG = <CONFIG>;
    close CONFIG;
  }
  
  my $expr = qr/[a-z0-9_@\-]+/;
  my %groups;
  my %repos;
  my $cur_repo = '';
  
  for my $line (@CONFIG) {
    given($line) {
      # group definition
      when(/^\s*@($expr)\s*=\s*($expr(?:\s+$expr)*)\s+$/i) {
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
      when(/^\s*([RW+\-CD]+)\s*=\s*($expr(?:\s+$expr)*)\s*$/) {
        unless(exists $repos{$cur_repo}) {
          %repos = (%repos, $cur_repo => { $1 => [split/ /, $2] });
        }
        else {
          $repos{$cur_repo} = { %{ $repos{$cur_repo} }, $1 => [split/ /, $2] };
        }
      }
    }
  }
  
  return(\%groups, \%repos);
}


sub get_gitolite_config_from_db {
  my @groups = Model->new('group')->list;
  my @repos = Model->new('repo')->list;
  my %groups;
  my %repos;
  
  for my $g (@groups) {
    %groups = ( %groups, $g->{name} => [split/ /, $g->{list}] );
  }
  
  for my $r (@repos) {
    my $access = { split/\n/, $r->{list} };
    $access->{$_} = [ split/ /, $access->{$_} ] for keys %$access;
    %repos = (%repos, $r->{name} => $access);
  }
  
  return(\%groups, \%repos);
}


sub save_gitolite_config_to_db {
  my($groups, $repos) = @_;
  my $model = Model->new('group');
  $model->delete();
  
  # Load groups to database.
  while(my($name, $list) = each %$groups) {
    $model->create({name => $name, list => join(' ', @$list)});
  }
  
  # Load repos to database.
  $model = Model->new('repo');
  $model->delete();
  while(my($name, $access) = each %$repos) {
    my $text = '';
    $text .= "$_\n".join(' ', @{ $access->{$_} })."\n" for keys %$access;
    $model->create({name => $name, list => $text});
  }
}


sub generate_gitolite_config {
  my($groups, $repos) = @_;
  
  my $TEXT = "# Generated by Gitty\n";
  while(my($group, $users) = each %$groups) {
    $TEXT .= "\@$group = ".join(' ', @$users)."\n";
  }
  
  $TEXT .= "\n";
  while(my($repo, $data) = each %$repos) {
    $TEXT .= "repo $repo\n";
    while(my($access, $users) = each %$data) {
      $TEXT .= "\t$access = ".join(' ', @$users)."\n";
    }
    $TEXT .= "\n";
  }
  
  return $TEXT;
}


sub save_keys_to_fs {
  my $gl_dir = Model->new('config')->read(name => 'gl_dir')->{value};
  my $root = "$gl_dir/keydir/";
  my $model = Model->new('key');
  
  for my $user ( Model->new('user')->list ) {
    my @keys = $model->list({ user_id => $user->{id} });
    
    for my $k (@keys) {
      mkdir $root.$k->{id};
      open PUB, '>', $root.$k->{id}.'/'.$user->{name}.'.pub'
        or die "Can't write to public-key file.";
      print PUB $k->{key};
      close PUB;
    }
  }
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
  my @where;
  
  if ( $where ) {
    @where = $self->_prepare($where);
  } else {
    push @where, '1=1';
  }
  
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
    % if (session('id') > 0) {
      <a href="/user/keys">Keys</a>
      <a href="/user/home">Home</a>
    % } else {
      <a href="/user/login">Login</a>
    % }
    </div>
    % if (session('id') == 1) {
      <div>
        <a href="/admin/users">Users</a>
        <a href="/admin/config/startup">Startup-Config</a>
        <a href="/admin/config/running">Running-Config</a>
        <a href="/admin/config/gitty">Gitty-Config</a>
      </div>
    % }
  <%= content %>
  </body>
</html>


@@ install.html.ep
% layout 'default', title => 'Installed';
<h1>Gitty config</h1>
<div class="error">
% if ($error eq 'bad_params') {
  Something went wrong!
% }
</div>
<form action="/install" method="POST">
<table>
  <tr>
    <td>Admin password</td>
    <td><input name="pass" type="password"></td>
  </tr>
  <tr>
    <td>Retype password</td>
    <td><input name="pass2" type="password"></td>
  </tr>
  <tr>
    <td>Salt</td>
    <td><input name="salt" value="<%= $salt %>"></td>
  </tr>
  <tr>
    <td>Secret key</td>
    <td><input name="secret_key" value="<%= $secret_key %>"></td>
  </tr>
  <tr>
    <td>Gitolite dir</td>
    <td><input name="gl_dir" value="./gitolite-admin"></td>
  </tr>
  <tr>
    <td colspan=2>
      <input type="submit" value="Install">
    </td>
  </tr>
</table>
</form>


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


@@ admin/repos.html.ep
% layout 'default', title => 'Repositories';
<form action="/user/repos" method="POST">
  <table>
    <tr>
      <td>Name</td>
      <td><input name="name"></td>
    </tr>
    <tr>
      <td>Description</td>
      <td><textarea name="desc"></textarea></td>
    </tr>
    <tr>
      <td>Users or groups</td>
      <td><textarea name="list"></textarea></td>
    </tr>
    <tr>
      <td colspan=2><input type="submit" value="Add"></td>
    </tr>
  </table>
</form>


@@ admin/groups.html.ep
% layout 'default', title => 'Groups';
<form action="/user/groups" method="POST">
  <table>
    <tr>
      <td>Name</td>
      <td><input name="name"></td>
    </tr>
    <tr>
      <td>Description</td>
      <td><textarea name="desc"></textarea></td>
    </tr>
    <tr>
      <td>Users or groups</td>
      <td><textarea name="list"></textarea></td>
    </tr>
    <tr>
      <td colspan=2><input type="submit" value="Add"></td>
    </tr>
  </table>
</form>


@@ admin/startup.html.ep
% layout 'default', title => 'Startup config';
<form action="/admin/config/startup" method="POST">
  <input type="submit" value="Copy startup-config to running-config">
</form>
<h2>Groups</h2>
<ul>
% while(my($name, $list) = each %$groups) {
  <li><b><%= $name %></b>
    <ul>
    % for my $item (@$list) {
      <li><%= $item %></li>
    % }
    </ul>
  </li>
%}
</ul>
<h2>Repositories</h2>
<ul>
% while(my($name, $access) = each %$repos) {
  <li><b><%= $name %></b>
    <ul>
    % while(my($access, $list) = each %$access) {
      <li><i><%= $access %></i>
        <ul>
        % for my $item (@$list) {
          <li><%= $item %></li>
        % }
        </ul>
      </li>
    % }
    </ul>
  </li>
%}
</ul>


@@ admin/gitty.html.ep
% layout 'default', title => 'Gitty config';
<form action="/admin/config/gitty" method="POST">
  <table>
    <tr>
      <td>Gitolite directory (gl_dir)</td>
      <td><input name="gl_dir" value="<%= $gl_dir %>"></td>
    </tr>
    <tr>
      <td>Secret key (secret_key)</td>
      <td><input name="secret_key" value="<%= $secret_key %>"></td>
    </tr>
    <tr>
      <td colspan=2><input type="submit" value="Change"></td>
    </tr>
  </table>
</form>


@@ admin/running.html.ep
% layout 'default', title => 'Running config';
<form action="/admin/config/running/to/startup" method="POST">
  <input type="submit" value="Copy running-config to startup-config">
</form>
<h2>Groups</h2>
<ul>
% while(my($name, $list) = each %$groups) {
  <li><b><%= $name %></b>
    <ul>
    % for my $item (@$list) {
      <li><%= $item %></li>
    % }
    </ul>
  </li>
%}
</ul>
<h2>Repositories</h2>
<ul>
% while(my($name, $access) = each %$repos) {
  <li><b><%= $name %></b>
    <ul>
    % while(my($access, $list) = each %$access) {
      <li><i><%= $access %></i>
        <ul>
        % for my $item (@$list) {
          <li><%= $item %></li>
        % }
        </ul>
      </li>
    % }
    </ul>
  </li>
%}
</ul>
<hr>
<h2>Change running-config</h2>
<form action="/admin/config/running" method="POST">
  <textarea name="conf"><%= $conf %></textarea>
  <input type="submit" value="Change running-config">
</form>


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
