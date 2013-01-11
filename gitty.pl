#!/usr/bin/perl

use DBI;
use utf8;
use strict;
use warnings;
use feature ':5.10';
use Mojolicious::Lite;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use constant { true => 1, false => 0 };

our $VERSION = '1.alpha';


#--------------------------------------------------------------------- Init --#

our $dbh = DBI->connect("dbi:SQLite:dbname=./gitty.db",
                        '', '', { RaiseError => 1 })
            or die $DBI::errstr;


#-------------------------------------------------------------- Controllers --#

get '/' => sub {
  my $self = shift;
  # INSTALL database if doesn't exist.
  eval{ Model->new('config')->read(name => 'salt') };
  $self->redirect_to('/install') if $@;
  my @hi = qw/Greetings Hello Aloha Hóla Salut Bonjour Chao Salam Привет/;
  return $self->stash({hi => $hi[int rand scalar @hi]})->render('index');
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
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name VARCHAR(32) UNIQUE,
      value TEXT
    );
  });
  Model->new->raw(qq{INSERT INTO config VALUES(1, 'salt'      , '$salt');});
  Model->new->raw(qq{INSERT INTO config VALUES(2, 'secret_key', '$secret_key');});
  Model->new->raw(qq{INSERT INTO config VALUES(3, 'gl_dir'    , '$gl_dir');});
  
  Model->new->raw(q{
    CREATE TABLE user (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
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
      '$admin_password_hash', $time, 0, 'Gitty Admin');
  });
  
  Model->new->raw(q{
    CREATE TABLE key (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      name VARCHAR(32),
      key TEXT,
      FOREIGN KEY(user_id) REFERENCES user(id)
    );
  });
  
  Model->new->raw(q{
    CREATE TABLE 'group' (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name VARCHAR(32) UNIQUE,
      list TEXT
    );
  });
  
  Model->new->raw(q{
    CREATE TABLE repo (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name VARCHAR(32) UNIQUE,
      list TEXT
    );
  });
  #say Model->new('config')->read(name => 'secret_key')->{value};
  #app->secret( Model->new('config')->read(name => 'secret_key')->{value} );
  $self->session(id => 1, name => 'admin', mail => 'admin@gitty',
                 regdate => $time, key_count => 0);
  
  return $self->redirect_to('/admin');
};


get '/user/login' => sub {
  my $self = shift;
  $self->stash({error => ''});
  $self->render('user/login');
};


get '/user/logout' => sub {
  my $self = shift;
  $self->session(id => 0);
  $self->redirect_to('/');
};


post '/user/login' => sub {
  my $self = shift;
  my $user = $self->param('user');
  my $pass = $self->param('pass');
  $user = Model->new('user')->read(name => $user);
  
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


#------------------------------------------------------------- User section --#

group {
  under '/user' => sub {
    my $self = shift;
    return true if access('user', $self->session('id'));
    return false;
  };
  
  
  get '/home' => sub {
    my $self = shift;
    my $user_id = $self->session('id');
    my $user = Model->new('user')->read(id => $user_id);
    $self->stash({user => $user})->render('user/home');
  };
  
  
  post '/home' => sub {
    my $self = shift;
    my $pass = $self->param('password');
    my $time = $self->session('regdate');
    my $salt = Model->new('config')->read(name => 'salt')->{value};
    
    my $data = {
      mail => $self->param('mail'),
      info => $self->param('info'),
      };
    
    $data = { %$data, password => md5_hex("$salt-$time-$pass") } if $pass;
    Model->new('user')->update($data, { id => $self->session('id') });
    $self->redirect_to('/user/home');
  };
  
  
  get '/keys' => sub {
    my $self = shift;
    my @keys = Model->new('key')->list({user_id => $self->session('id')});
    $self->stash({keys => \@keys})->render('user/keys');
  };
  
  
  post '/keys' => sub {
    my $self = shift;
    my $name = $self->param('name');
    my $key  = $self->param('key');
    
    Model->new('key')->create({
      user_id => $self->session('id'),
      name => $name,
      key => $key
      });
    
    push_admin_config();
    
    $self->redirect_to('/user/keys');
  };
};


#------------------------------------------------------------ Admin section --#

group {
  under '/admin' => sub {
    my $self = shift;
    return true if access('admin', $self->session('id'));
    return false;
  };
  
  
  get '/' => sub {
    my $self = shift;
    $self->render('admin/index');
  };
  
  
  get '/users' => sub {
    my $self = shift;
    my @users = Model->new('user')->list;
    $self->stash({users => \@users})->render('admin/users');
  };
  
  
  post '/users' => sub {
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
  
  
  get '/repos' => sub {
    my $self = shift;
    my @groups = Model->new('group')->list;
    my @repos = Model->new('repo')->list;
    $self->stash({repos => \@repos, groups => \@groups})->render('admin/repos');
  };
  
  
  post '/repos' => sub {
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
  
  
  get '/groups' => sub {
    my $self = shift;
    my @groups = Model->new('group')->list;
    $self->stash({groups => \@groups})->render('admin/groups');
  };
  
  
  post '/groups' => sub {
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
  
  
  get '/config/startup' => sub {
    my $self = shift;
    my ($groups, $repos) = parse_gitolite_config();
    $self->stash({groups => $groups, repos => $repos})->render('admin/startup');
  };
  
  
  # Load startup-config.
  post '/config/startup' => sub {
    my $self = shift;
    my ($groups, $repos) = parse_gitolite_config();
    save_gitolite_config_to_db($groups, $repos);
    $self->redirect_to('/admin/config/running');
  };
  
  
  get '/config/gitty' => sub {
    my $self = shift;
    my $secret_key = Model->new('config')->read({name => 'secret_key'})->{value};
    my $gl_dir = Model->new('config')->read({name => 'gl_dir'})->{value};
    $self->stash({secret_key => $secret_key, gl_dir => $gl_dir})
      ->render('admin/gitty');
  };
  
  
  post '/config/gitty' => sub {
    my $self = shift;
    my $secret_key = $self->param('secret_key');
    my $gl_dir = $self->param('gl_dir');
    Model->new('config')->update({value => $secret_key}, {name => 'secret_key'});
    Model->new('config')->update({value => $gl_dir}, {name => 'gl_dir'});
    $self->redirect_to('/admin/config/gitty');
  };
  
  
  get '/config/running' => sub {
    my $self = shift;
    my ($groups, $repos) = get_gitolite_config_from_db();
    my $text = generate_gitolite_config($groups, $repos);
    
    $self->stash({groups => $groups, repos => $repos, conf => $text})
      ->render('admin/running');
  };
  
  
  # Save running-config to startup-config.
  post '/config/running/to/startup' => sub {
    my $self = shift;
    my $gl_dir = Model->new('config')->read(name => 'gl_dir')->{value};
    my ($groups, $repos) = get_gitolite_config_from_db();
    my $text = generate_gitolite_config($groups, $repos);
    
    open CONFIG, ">$gl_dir/conf/gitolite.conf"
      or die "Can't find gitolite config file.";
    print CONFIG $text;
    close CONFIG;
    
    push_admin_config();
    
    $self->redirect_to('/admin/config/running');
  };
  
  
  post '/config/running' => sub {
    my $self = shift;
    my $conf = $self->param('conf');
    my ($groups, $repos) = parse_gitolite_config($conf);
    save_gitolite_config_to_db($groups, $repos);
    $self->redirect_to('/admin/config/running');
  };
};

app->start;


#--------------------------------------------------------- Useful functions --#

sub access {
  my $level = shift || 'user'; # required access level
  my $user_id = shift || 0;
  
  given($level) {
    when('user') { return true if $user_id }
    when('admin') { return true if $user_id == 1 }
  }
  
  return false;
}


sub push_admin_config {
  my $self = shift;
  my $gl_dir = Model->new('config')->read(name => 'gl_dir')->{value};
  save_keys_to_fs();
  
  $self->app->log->warn(
    "Update admin config...\n" .
    `cd $gl_dir && git add . && git commit -m 'update' && git push`);
}


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
      my $dir = $root.$user->{name}.'_'.$k->{id};
      mkdir $dir unless -d $dir;
      my $file = $dir.'/'.$user->{name}.'.pub';
      
      if (-r $file) {
        open PUB, "> $file" or die "Can't write to public-key file.";
      }
      else {
        open PUB, ">> $file" or die "Can't write to public-key file.";
      }
      
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
@@ css/style.css
nav, header, article, footer { display: block; }
html {
  padding:0px;
  margin:0px;
  height: 80%;
  /* Gradient */
  filter: progid:DXImageTransform.Microsoft.gradient(startColorstr='#5699A9', endColorstr='#ffffff'); /* for IE */
  background: -webkit-gradient(linear, left top, left bottom, from(#5699A9), to(#ffffff)); /* for webkit browsers */
  background: -moz-linear-gradient(top, #5699A9, #ffffff); /* for firefox 3.6+ */
  background-repeat: no-repeat;
}
body {
  padding:0px;
  margin:10px 0px 0px 0px;
  height:120%;
  width:100%;
  font-family:Sans;
  color:#444;
  font-size: 14px;
}
a { color: #26c; text-decoration: none; }
h1,h2,h3,h4,h5,h6 { padding-top:0px; margin-top:0px; }
.cb { clear: both; }
body>nav {
  width:600px;
  margin:0px auto;
  padding:0px 10px 0px 10px;
}
.done, .error, .info, .rounded {
  padding: 10px;
  padding-right: 15px;
  background:#F2F1F0;
  border: 1px solid #ddd;
  -moz-border-radius: 5px;
  -webkit-border-radius: 5px;
  border-radius: 5px;
  -khtml-border-radius: 5px;
}
.done, .error, .info { text-align:center; margin: 0px; }
.info { background: #ffd; border: 1px solid #fff7dd; }
.error { background: #fee; border: 1px solid #fcc; margin: 0px auto; }
.done { background: #efe; border: 1px solid #cfc; }
.hidden { display:none; }
.aligncenter { margin:auto; }
.alignright { float:right; }
.alignleft { float:left; }
.page {
  margin:0px auto;
  padding:10px 10px 0px 10px;
  width:600px;
  height:100%;
  color:#222;
  font-family:Sans, Arial;
  background:#fff;
  border: 1px solid #fff;
  -moz-border-radius:10px 10px 0px 0px;
  -webkit-border-radius:10px 10px 0px 0px;
  border-radius:10px 10px 0px 0px;
  -khtml-border-radius:10px 10px 0px 0px;
}
body>header>h1 { color: #fff; }
body>header { margin:20px auto; width:600px; }
body>footer { margin:0px auto 20px auto; width:600px; }
.form { width:300px; }
.form td { padding:5px; }
.icon { height: 32px; }
.wide { display:block; width:100%; }
body>nav>div>a { background: #fff; color: #a44; padding: 4px; margin-right: 10px; display: block; float: left;   -moz-border-radius: 5px;  -webkit-border-radius: 5px;  border-radius: 5px;  -khtml-border-radius: 5px;}
body>nav>div>a:hover { color: #a00; text-decoration: underline; }


@@ layouts/default.html.ep
<!doctype html>
<html>
<head>
<title><%= title %></title>
<link href="/css/style.css" rel="stylesheet">
</head>
  <body>
    <nav>
      % if (session('id') && session('id') == 1) {
        <div>
          <a href="/admin/users">Users</a>
          <a href="/admin/config/startup">Startup-Config</a>
          <a href="/admin/config/running">Running-Config</a>
          <a href="/admin/config/gitty">Gitty-Config</a>
        </div>
      % }
    </nav>
    <div class=cb></div>
    <header>
      <div class="alignright">
      % if (session('id') && session('id') > 0) {
        <a href="/user/home"><img src="/pic/home.svg" class="icon" alt="Home" title="Home"></a>
        <a href="/user/keys"><img src="/pic/keys.svg" class="icon" alt="Keys" title="Keys"></a>
        <a href="/user/logout"><img src="/pic/exit.svg" class="icon" alt="Logout" title="Logout"></a>
      % } else {
        <a href="/user/login"><img src="/pic/exit.svg" class="icon" alt="Login" title="Login"></a>
      % }
      </div>
      <h1><%= title %></h1>
    </header>
    <div class=cb></div>
    <article class="page">
      <%= content %>
    </article>
    
    <footer>
      <div style="text-align:center;font-size:10px;">Powered by <a href="http://github.com/h15/gitty">Gitty</a> /
        <a href="http://mojolicio.us">Mojolicious</a> /
        <a href="http://perl.org">Perl</a>
      </div>
    </footer>
  </body>
</html>


@@ install.html.ep
% layout 'default', title => 'Install Gitty';
% if ($error) {
  <div class="error">
  % if ($error eq 'bad_params') {
    Bad params!
  % }
  </div>
% }
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
% layout 'default', title => $hi;


@@ user/login.html.ep
% layout 'default', title => 'Login';
% if ($error) {
  <div class="error"><%= $error %></div>
% }
<form action="/user/login" method="POST">
<table class="form aligncenter" style="margin-top:30px;">
  <tr>
    <td>Name</td>
    <td><input name="user" class="wide"></td>
  </tr>
  <tr>
    <td>Password</td>
    <td><input name="pass" class="wide" type="password"></td>
  <tr>
  <tr>
    <td colspan=2>
      <input type="submit" value="Login" class="alignright">
    </td>
  </tr>
</table>
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
      <td><%= $user->{name} %></td>
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
  <textarea name="conf" class="wide" style="height:200px;"><%= $conf %></textarea>
  <input type="submit" value="Change running-config">
</form>


@@ not_found.html.ep
% layout 'default', title => 'Page does not found';


@@ pic/exit.svg
<?xml version="1.0" encoding="UTF-8" standalone="no"?> <!-- Created with Inkscape (http://www.inkscape.org/) --> <svg xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:cc="http://creativecommons.org/ns#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" width="48px" height="48px" id="svg7212" sodipodi:version="0.32" inkscape:version="0.46" sodipodi:docname="drawing-3.svg" inkscape:output_extension="org.inkscape.output.svg.inkscape"> <defs id="defs7214"> <linearGradient id="linearGradient9896"> <stop id="stop9898" offset="0" style="stop-color:#cecece;stop-opacity:1;" /> <stop id="stop9900" offset="1.0000000" style="stop-color:#9e9e9e;stop-opacity:1.0000000;" /> </linearGradient> <linearGradient gradientUnits="userSpaceOnUse" y2="18.064039" x2="33.710651" y1="21.511185" x1="31.078955" id="linearGradient9902" xlink:href="#linearGradient9896" inkscape:collect="always" gradientTransform="translate(-3.6735026e-4,-2.381e-4)" /> <linearGradient id="linearGradient9880" inkscape:collect="always"> <stop id="stop9882" offset="0" style="stop-color:#525252;stop-opacity:1;" /> <stop id="stop9884" offset="1" style="stop-color:#525252;stop-opacity:0;" /> </linearGradient> <linearGradient gradientTransform="translate(-1.1164876,-2.381e-4)" gradientUnits="userSpaceOnUse" y2="24.764584" x2="34.007416" y1="19.107729" x1="31.852951" id="linearGradient9886" xlink:href="#linearGradient9880" inkscape:collect="always" /> <linearGradient id="linearGradient9868"> <stop style="stop-color:#4e4e4e;stop-opacity:1.0000000;" offset="0.0000000" id="stop9870" /> <stop style="stop-color:#616161;stop-opacity:0.0000000;" offset="1.0000000" id="stop9872" /> </linearGradient> <radialGradient gradientUnits="userSpaceOnUse" gradientTransform="matrix(2.565823,0,0,1.403262,-37.783598,-9.4835408)" r="9.7227182" fy="7.1396070" fx="27.883883" cy="7.1396070" cx="27.883883" id="radialGradient9876" xlink:href="#linearGradient9868" inkscape:collect="always" /> <linearGradient id="linearGradient9888" inkscape:collect="always"> <stop id="stop9890" offset="0" style="stop-color:#ffffff;stop-opacity:1;" /> <stop id="stop9892" offset="1" style="stop-color:#ffffff;stop-opacity:0;" /> </linearGradient> <linearGradient gradientUnits="userSpaceOnUse" y2="43.449947" x2="19.755548" y1="13.663074" x1="8.7600641" id="linearGradient9894" xlink:href="#linearGradient9888" inkscape:collect="always" gradientTransform="translate(-3.6735026e-4,-2.381e-4)" /> <linearGradient id="linearGradient3197"> <stop style="stop-color:#da3f3f;stop-opacity:1;" offset="0" id="stop3199" /> <stop style="stop-color:#c22f2f;stop-opacity:1;" offset="1" id="stop3201" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3197" id="linearGradient3203" x1="11.131293" y1="15.165678" x2="11.118231" y2="32.401405" gradientUnits="userSpaceOnUse" gradientTransform="translate(-3.6735026e-4,-2.381e-4)" /> <linearGradient inkscape:collect="always" id="linearGradient8662"> <stop style="stop-color:#000000;stop-opacity:1;" offset="0" id="stop8664" /> <stop style="stop-color:#000000;stop-opacity:0;" offset="1" id="stop8666" /> </linearGradient> <radialGradient r="15.644737" fy="36.421127" fx="24.837126" cy="36.421127" cx="24.837126" gradientTransform="matrix(1,0,0,0.536723,0,16.87306)" gradientUnits="userSpaceOnUse" id="radialGradient9826" xlink:href="#linearGradient8662" inkscape:collect="always" /> <linearGradient id="linearGradient9854"> <stop id="stop9856" offset="0.0000000" style="stop-color:#4e4e4e;stop-opacity:1.0000000;" /> <stop id="stop9858" offset="1.0000000" style="stop-color:#ababab;stop-opacity:1.0000000;" /> </linearGradient> <linearGradient gradientUnits="userSpaceOnUse" y2="27.759069" x2="18.031221" y1="19.804117" x1="46.845825" id="linearGradient9864" xlink:href="#linearGradient9854" inkscape:collect="always" gradientTransform="translate(-3.6735026e-4,-2.381e-4)" /> <linearGradient id="linearGradient9842" inkscape:collect="always"> <stop id="stop9844" offset="0" style="stop-color:#727e0a;stop-opacity:1;" /> <stop id="stop9846" offset="1" style="stop-color:#727e0a;stop-opacity:0;" /> </linearGradient> <linearGradient gradientTransform="matrix(1.025512,0,0,0.648342,-0.8658636,15.630022)" gradientUnits="userSpaceOnUse" y2="28.112619" x2="30.935921" y1="43.757359" x1="30.935921" id="linearGradient9848" xlink:href="#linearGradient9842" inkscape:collect="always" /> <linearGradient id="linearGradient9830"> <stop id="stop9832" offset="0.0000000" style="stop-color:#505050;stop-opacity:1.0000000;" /> <stop id="stop9834" offset="1.0000000" style="stop-color:#181818;stop-opacity:1.0000000;" /> </linearGradient> <radialGradient gradientUnits="userSpaceOnUse" gradientTransform="matrix(2.0182701,0,0,2.643808,-144.57335,-62.192134)" r="16.321514" fy="40.545052" fx="93.780037" cy="40.545052" cx="93.780037" id="radialGradient9836" xlink:href="#linearGradient9830" inkscape:collect="always" /> </defs> <sodipodi:namedview id="base" pagecolor="#ffffff" bordercolor="#666666" borderopacity="1.0" inkscape:pageopacity="0.0" inkscape:pageshadow="2" inkscape:zoom="7" inkscape:cx="24" inkscape:cy="24" inkscape:current-layer="layer1" showgrid="true" inkscape:grid-bbox="true" inkscape:document-units="px" inkscape:window-width="641" inkscape:window-height="690" inkscape:window-x="474" inkscape:window-y="258" /> <metadata id="metadata7217"> <rdf:RDF> <cc:Work rdf:about=""> <dc:format>image/svg+xml</dc:format> <dc:type rdf:resource="http://purl.org/dc/dcmitype/StillImage" /> </cc:Work> </rdf:RDF> </metadata> <g id="layer1" inkscape:label="Layer 1" inkscape:groupmode="layer"> <rect ry="1.0048841" rx="0.99447322" y="1" x="12" height="45" width="35" id="rect8242" style="opacity:0.7;fill:#000000;fill-opacity:0.31372549;fill-rule:evenodd;stroke:none;stroke-width:1.00001979;stroke-linecap:butt;stroke-linejoin:miter;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:10;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" inkscape:r_cx="true" inkscape:r_cy="true" /> <rect ry="0.70808184" rx="0.70720309" y="2.5000091" x="13.50001" height="41.999981" width="31.999981" id="rect9828" style="opacity:1;fill:url(#radialGradient9836);fill-opacity:1;fill-rule:evenodd;stroke:#000000;stroke-width:1.00001979;stroke-linecap:butt;stroke-linejoin:miter;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:10;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" inkscape:r_cx="true" inkscape:r_cy="true" /> <rect y="31.736305" x="13.999632" height="12.263458" width="30.999998" id="rect9840" style="opacity:1;fill:url(#linearGradient9848);fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1;stroke-linecap:butt;stroke-linejoin:miter;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:10;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" inkscape:r_cx="true" inkscape:r_cy="true" /> <path sodipodi:nodetypes="ccccc" id="path9852" d="M 14.037294,43.944621 L 13.998461,3.0542871 L 33.940757,3.0984813 L 33.984951,33.017937 L 14.037294,43.944621 z" style="opacity:1;fill:url(#linearGradient9864);fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1;stroke-linecap:butt;stroke-linejoin:miter;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:10;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" /> <path style="opacity:0.42222224;fill:#ffffff;fill-opacity:1;fill-rule:nonzero;stroke:none;stroke-width:3;stroke-linecap:round;stroke-linejoin:round;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1;visibility:visible;display:block;overflow:visible" d="M 13.969433,43.944621 L 34.117535,33.062131 L 15.555981,41.989354 L 15.555981,3.0100925 L 13.985518,3.0100925 L 13.969433,43.944621 z" id="path1360" inkscape:r_cx="true" inkscape:r_cy="true" sodipodi:nodetypes="cccccc" /> <path sodipodi:type="arc" style="opacity:0.29946522;fill:url(#radialGradient9826);fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1;stroke-linecap:butt;stroke-linejoin:miter;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:10;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" id="path8660" sodipodi:cx="24.837126" sodipodi:cy="36.421127" sodipodi:rx="15.644737" sodipodi:ry="8.3968935" d="M 40.481863,36.421127 A 15.644737,8.3968935 0 1 1 9.1923885,36.421127 A 15.644737,8.3968935 0 1 1 40.481863,36.421127 z" transform="matrix(0.77849,0,0,0.77849,-7.5801826,1.5979009)" /> <path style="opacity:1;fill:url(#linearGradient3203);fill-opacity:1;fill-rule:evenodd;stroke:#a40000;stroke-width:0.99999982;stroke-linecap:round;stroke-linejoin:round;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:10;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" d="M 1.7314304,17.593581 L 1.7314304,30.355126 L 9.663735,30.355126 L 9.663735,36.175909 L 21.887377,23.952265 L 9.590974,11.655863 L 9.590974,17.596829 L 1.7314304,17.593581 z" id="path8643" sodipodi:nodetypes="cccccccc" /> <path sodipodi:nodetypes="cccccccc" id="path8658" d="M 2.7189574,18.399747 L 2.7189574,29.535791 L 10.552776,29.535791 L 10.552776,33.793741 L 20.404229,23.948168 L 10.488209,13.684476 L 10.488209,18.402629 L 2.7189574,18.399747 z" style="opacity:0.48128339;fill:none;fill-opacity:1;fill-rule:evenodd;stroke:url(#linearGradient9894);stroke-width:1;stroke-linecap:butt;stroke-linejoin:miter;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:10;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" /> <path style="opacity:1;fill:url(#radialGradient9876);fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1;stroke-linecap:butt;stroke-linejoin:miter;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:10;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" d="M 14.044443,43.757121 L 13.999632,3.0542871 L 33.940757,3.0542871 L 33.761511,33.68085 L 14.044443,43.757121 z" id="path9866" sodipodi:nodetypes="ccccc" inkscape:r_cx="true" inkscape:r_cy="true" /> <path sodipodi:nodetypes="cccsscc" id="path9878" d="M 29.642657,18.455957 L 31.565104,20.908733 L 30.106696,25.725898 C 30.106696,25.725898 30.371861,27.2285 31.145259,26.212034 C 31.918657,25.195568 34.117714,22.62998 33.730618,20.754053 C 33.443356,19.361937 32.647861,18.699025 32.647861,18.699025 L 29.642657,18.455957 z" style="opacity:1;fill:url(#linearGradient9886);fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1;stroke-linecap:butt;stroke-linejoin:miter;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:10;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" /> <path sodipodi:nodetypes="csccscs" id="path9862" d="M 31.476716,17.351102 C 31.476716,17.351102 33.639986,18.35282 33.708521,19.229355 C 33.810302,20.531077 29.46588,24.665238 29.46588,24.665238 C 28.957647,25.283956 28.117958,24.731529 28.581997,24.134908 C 28.581997,24.134908 32.048601,20.016935 31.830269,19.693393 C 31.556658,19.287936 29.863628,18.65483 29.863628,18.65483 C 28.847162,17.90353 30.131249,16.349367 31.476716,17.351102 z" style="opacity:1;fill:url(#linearGradient9902);fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1;stroke-linecap:butt;stroke-linejoin:miter;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:10;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" /> </g> </svg>


@@ pic/keys.svg
<?xml version="1.0" encoding="UTF-8" standalone="no"?> <!-- Created with Inkscape (http://www.inkscape.org/) --> <svg xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:cc="http://creativecommons.org/ns#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" width="48px" height="48px" id="svg7456" sodipodi:version="0.32" inkscape:version="0.46" sodipodi:docname="drawing.svg" inkscape:output_extension="org.inkscape.output.svg.inkscape"> <defs id="defs7458"> <linearGradient id="linearGradient7567" inkscape:collect="always"> <stop id="stop7569" offset="0" style="stop-color:#000000;stop-opacity:1;" /> <stop id="stop7571" offset="1" style="stop-color:#000000;stop-opacity:0;" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient7567" id="linearGradient9719" gradientUnits="userSpaceOnUse" gradientTransform="matrix(-0.235981,-1.1304264,0.6373638,-0.915432,7.1985993,53.314931)" x1="20.722668" y1="16.830494" x2="22.697027" y2="15.894469" /> <linearGradient id="linearGradient7549" inkscape:collect="always"> <stop id="stop7551" offset="0" style="stop-color:#ffffff;stop-opacity:1" /> <stop id="stop7553" offset="1" style="stop-color:#eeeeec;stop-opacity:1" /> </linearGradient> <radialGradient inkscape:collect="always" xlink:href="#linearGradient7549" id="radialGradient9717" gradientUnits="userSpaceOnUse" gradientTransform="matrix(-0.3629926,-1.6372128,1.8500902,-2.1525103,1.7477513,74.824986)" cx="24.090876" cy="5.052979" fx="24.090876" fy="5.052979" r="4.4921517" /> <linearGradient id="linearGradient7592" inkscape:collect="always"> <stop id="stop7594" offset="0" style="stop-color:#ffffff;stop-opacity:1;" /> <stop id="stop7596" offset="1" style="stop-color:#ffffff;stop-opacity:0;" /> </linearGradient> <radialGradient inkscape:collect="always" xlink:href="#linearGradient7592" id="radialGradient9715" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1,0,0,0.6206897,0,0.7823276)" cx="11.15625" cy="2.0625" fx="11.15625" fy="2.0625" r="0.90625" /> <linearGradient id="linearGradient7491" inkscape:collect="always"> <stop id="stop7493" offset="0" style="stop-color:#eeeeec;stop-opacity:1" /> <stop id="stop7495" offset="1" style="stop-color:#babdb6;stop-opacity:1" /> </linearGradient> <radialGradient inkscape:collect="always" xlink:href="#linearGradient7491" id="radialGradient9713" gradientUnits="userSpaceOnUse" gradientTransform="matrix(-0.1907818,1.5922835,-1.4345654,1.1802872,15.217766,-19.515538)" cx="23.681061" cy="5.3414755" fx="23.681061" fy="5.3414755" r="5.055244" /> <linearGradient id="linearGradient3781" inkscape:collect="always"> <stop id="stop3783" offset="0" style="stop-color:#ce5c00;stop-opacity:1" /> <stop id="stop3785" offset="1" style="stop-color:#ce5c00;stop-opacity:0" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3781" id="linearGradient9711" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0.727273,0,0,0.999999,12.27273,-34.84375)" x1="33.120464" y1="20.5" x2="22.328388" y2="20.5" /> <linearGradient inkscape:collect="always" xlink:href="#linearGradient2816" id="linearGradient9709" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0,0.673693,-0.676136,0,37.10227,14.81577)" x1="15.406166" y1="37.34367" x2="16.864777" y2="24.249567" /> <linearGradient inkscape:collect="always" id="linearGradient3787"> <stop style="stop-color:#f57900;stop-opacity:1" offset="0" id="stop3789" /> <stop style="stop-color:#f57900;stop-opacity:0" offset="1" id="stop3791" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3787" id="linearGradient9707" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0,0.625,-0.676136,0,37.10227,15.875)" x1="17" y1="45.248375" x2="17" y2="30.759407" /> <linearGradient id="linearGradient3793" inkscape:collect="always"> <stop id="stop3795" offset="0" style="stop-color:#ce5c00;stop-opacity:1;" /> <stop id="stop3797" offset="1" style="stop-color:#f57900;stop-opacity:1" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3793" id="linearGradient9705" gradientUnits="userSpaceOnUse" x1="9.172595" y1="35.541569" x2="19.208227" y2="33.578098" /> <linearGradient id="linearGradient7614" inkscape:collect="always"> <stop id="stop7616" offset="0" style="stop-color:#fcaf3e;stop-opacity:1" /> <stop style="stop-color:#fff6a1;stop-opacity:1" offset="0.4873454" id="stop7628" /> <stop id="stop7618" offset="1" style="stop-color:#fcaf3e;stop-opacity:1" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient7614" id="linearGradient9703" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0,0.673693,-0.676136,0,37.10227,14.81577)" x1="1.6736434" y1="24.765099" x2="47.084221" y2="45.634029" /> <linearGradient id="linearGradient3801" inkscape:collect="always"> <stop id="stop3803" offset="0" style="stop-color:#729fcf;stop-opacity:1" /> <stop id="stop3805" offset="1" style="stop-color:#729fcf;stop-opacity:0" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3801" id="linearGradient9701" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0.727273,0,0,0.999999,12.27273,-34.84375)" x1="33.120464" y1="20.5" x2="22.328388" y2="20.5" /> <linearGradient inkscape:collect="always" xlink:href="#linearGradient2816" id="linearGradient9699" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0,0.673693,-0.676136,0,37.10227,14.81577)" x1="15.406166" y1="37.34367" x2="16.864777" y2="24.249567" /> <linearGradient inkscape:collect="always" xlink:href="#linearGradient6958" id="linearGradient9697" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0,0.625,-0.676136,0,37.10227,15.875)" x1="17" y1="45.248375" x2="17" y2="30.759407" /> <linearGradient id="linearGradient3813" inkscape:collect="always"> <stop id="stop3815" offset="0" style="stop-color:#3465a4;stop-opacity:1" /> <stop id="stop3817" offset="1" style="stop-color:#729fcf;stop-opacity:1" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3813" id="linearGradient9695" gradientUnits="userSpaceOnUse" x1="7.9505267" y1="36.094822" x2="13.654268" y2="33.390598" /> <linearGradient id="linearGradient3807" inkscape:collect="always"> <stop id="stop3809" offset="0" style="stop-color:#729fcf;stop-opacity:1" /> <stop id="stop3811" offset="1" style="stop-color:#ffffff;stop-opacity:1" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3807" id="linearGradient9693" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0,0.673693,-0.676136,0,37.10227,14.81577)" x1="33.258583" y1="45.029243" x2="32.347187" y2="32.298042" /> <linearGradient inkscape:collect="always" id="linearGradient4542"> <stop style="stop-color:#888a85;stop-opacity:1" offset="0" id="stop4544" /> <stop style="stop-color:#888a85;stop-opacity:0" offset="1" id="stop4546" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient4542" id="linearGradient9691" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0.727273,0,0,0.999999,12.27273,-34.84375)" x1="33.120464" y1="20.5" x2="22.328388" y2="20.5" /> <linearGradient inkscape:collect="always" id="linearGradient2816"> <stop style="stop-color:white;stop-opacity:1;" offset="0" id="stop2818" /> <stop style="stop-color:white;stop-opacity:0;" offset="1" id="stop2820" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient2816" id="linearGradient9689" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0,0.673693,-0.676136,0,37.10227,14.81577)" x1="15.406166" y1="37.34367" x2="16.864777" y2="24.249567" /> <linearGradient id="linearGradient6958" inkscape:collect="always"> <stop id="stop6960" offset="0" style="stop-color:#000000;stop-opacity:1" /> <stop id="stop6962" offset="1" style="stop-color:#888a85;stop-opacity:0;" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient6958" id="linearGradient9687" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0,0.625,-0.676136,0,37.10227,15.875)" x1="17" y1="45.248375" x2="17" y2="30.759407" /> <linearGradient inkscape:collect="always" id="linearGradient6826"> <stop style="stop-color:#babdb6;stop-opacity:1" offset="0" id="stop6828" /> <stop style="stop-color:#eeeeec;stop-opacity:1" offset="1" id="stop6830" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient6826" id="linearGradient9685" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0,0.673693,-0.676136,0,37.10227,14.81577)" x1="13.819278" y1="30.029789" x2="36.227631" y2="45.194965" /> <radialGradient inkscape:collect="always" xlink:href="#linearGradient3823" id="radialGradient9683" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1,0,0,0.1983471,0,33.377652)" cx="24.57196" cy="41.63604" fx="24.57196" fy="41.63604" r="21.38998" /> <linearGradient id="linearGradient3823" inkscape:collect="always"> <stop id="stop3825" offset="0" style="stop-color:#000000;stop-opacity:1;" /> <stop id="stop3827" offset="1" style="stop-color:#000000;stop-opacity:0;" /> </linearGradient> <radialGradient inkscape:collect="always" xlink:href="#linearGradient3823" id="radialGradient9681" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1,0,0,0.1983471,0,33.377652)" cx="24.57196" cy="41.63604" fx="24.57196" fy="41.63604" r="21.38998" /> <linearGradient id="linearGradient7582" inkscape:collect="always"> <stop id="stop7584" offset="0" style="stop-color:#ffffff;stop-opacity:1;" /> <stop id="stop7586" offset="1" style="stop-color:#ffffff;stop-opacity:0;" /> </linearGradient> <radialGradient inkscape:collect="always" xlink:href="#linearGradient7582" id="radialGradient9679" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1,0,0,0.6206897,0,0.7823276)" cx="11.15625" cy="2.0625" fx="11.15625" fy="2.0625" r="0.90625" /> <linearGradient id="linearGradient7557" inkscape:collect="always"> <stop id="stop7559" offset="0" style="stop-color:#eeeeec;stop-opacity:1" /> <stop id="stop7561" offset="1" style="stop-color:#eeeeec;stop-opacity:1" /> </linearGradient> <radialGradient inkscape:collect="always" xlink:href="#linearGradient7557" id="radialGradient9677" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0,-1,0.6315789,0,2.6079603,38.294806)" cx="17.812502" cy="14.729167" fx="17.812502" fy="14.729167" r="9.500001" /> </defs> <sodipodi:namedview id="base" pagecolor="#ffffff" bordercolor="#666666" borderopacity="1.0" inkscape:pageopacity="0.0" inkscape:pageshadow="2" inkscape:zoom="7" inkscape:cx="24" inkscape:cy="24" inkscape:current-layer="layer1" showgrid="true" inkscape:grid-bbox="true" inkscape:document-units="px" inkscape:window-width="641" inkscape:window-height="690" inkscape:window-x="220" inkscape:window-y="286" /> <metadata id="metadata7461"> <rdf:RDF> <cc:Work rdf:about=""> <dc:format>image/svg+xml</dc:format> <dc:type rdf:resource="http://purl.org/dc/dcmitype/StillImage" /> </cc:Work> </rdf:RDF> </metadata> <g id="layer1" inkscape:label="Layer 1" inkscape:groupmode="layer"> <g style="display:inline;enable-background:new" id="g9613" inkscape:label="Livello 1" transform="translate(0.3387477,0.661727)"> <path style="fill:none;stroke:#babdb6;stroke-width:3;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dashoffset:0.69999992;stroke-opacity:1" d="M 13.078183,14.013633 C 13.599229,16.509614 11.595025,22.021303 8.604514,26.31651 C 5.6140033,30.611717 2.7640443,32.071958 2.2429983,29.575977" id="path9615" sodipodi:nodetypes="css" /> <path style="fill:none;stroke:url(#radialGradient9677);stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dashoffset:0.69999992;stroke-opacity:1" d="M 6.7166663,17.273099 C 9.707177,12.977892 12.557137,11.517651 13.078183,14.013633 C 13.599229,16.509614 11.595025,22.021303 8.604514,26.31651 C 5.6140033,30.611717 2.7640443,32.071958 2.2429983,29.575977 C 1.7219523,27.079995 3.7261553,21.568306 6.7166663,17.273099 L 6.7166663,17.273099 z" id="path9617" /> <path sodipodi:type="arc" style="fill:url(#radialGradient9679);fill-opacity:1;fill-rule:evenodd;stroke:none;marker:none;marker-start:none;marker-mid:none;marker-end:none;visibility:visible;display:inline;overflow:visible;enable-background:accumulate" id="path9619" sodipodi:cx="11.15625" sodipodi:cy="2.0625" sodipodi:rx="0.90625" sodipodi:ry="0.5625" d="M 12.0625,2.0625 A 0.90625,0.5625 0 1 1 10.25,2.0625 A 0.90625,0.5625 0 1 1 12.0625,2.0625 z" transform="matrix(0,-1.1034483,1.7777778,0,6.6698473,35.658005)" /> <g style="opacity:0.82173923" id="g9621"> <path sodipodi:type="arc" style="opacity:0.15217393;fill:url(#radialGradient9681);fill-opacity:1;stroke:none" id="path9623" sodipodi:cx="24.57196" sodipodi:cy="41.63604" sodipodi:rx="21.38998" sodipodi:ry="4.2426405" d="M 45.961941,41.63604 A 21.38998,4.2426405 0 1 1 3.1819801,41.63604 A 21.38998,4.2426405 0 1 1 45.961941,41.63604 z" transform="matrix(1.0730482,0,0,1.3541667,-2.2852925,-15.780108)" /> <path sodipodi:type="arc" style="opacity:0.15217393;fill:url(#radialGradient9683);fill-opacity:1;stroke:none" id="path9625" sodipodi:cx="24.57196" sodipodi:cy="41.63604" sodipodi:rx="21.38998" sodipodi:ry="4.2426405" d="M 45.961941,41.63604 A 21.38998,4.2426405 0 1 1 3.1819801,41.63604 A 21.38998,4.2426405 0 1 1 45.961941,41.63604 z" transform="matrix(0.4974282,0,0,0.6617912,14.622682,12.732021)" /> </g> <g transform="matrix(1.0960268,-0.6327913,0.6327913,1.0960268,-15.036604,-0.7801997)" id="g9627"> <path sodipodi:nodetypes="csccccccccccccccccsccsssc" style="fill:url(#linearGradient9685);fill-opacity:1;fill-rule:evenodd;stroke:#888a85;stroke-width:0.79014969;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1" d="M 13.4375,16.5 C 9.5186162,16.499999 6.34375,19.657775 6.34375,23.5625 C 6.3437502,26.380698 7.9483759,28.863095 10.34375,30 L 10.34375,31.5 L 11.84375,33 L 10.34375,34.5 L 10.34375,35.5 L 12.34375,36.5 L 12.34375,37.5 L 10.34375,38.5 L 10.34375,39.5 L 11.84375,41 L 10.34375,42.5 L 10.34375,43.5 L 12.84375,45.5 L 15.34375,45.5 L 16.34375,44 L 16.34375,30 C 18.716179,28.854566 20.34375,26.301484 20.34375,23.5 C 20.34375,19.595276 17.356384,16.5 13.4375,16.5 z M 13.34375,18.5 C 14.44775,18.5 15.34375,19.396 15.34375,20.5 C 15.34375,21.604 14.44775,22.5 13.34375,22.5 C 12.23975,22.5 11.34375,21.604 11.34375,20.5 C 11.34375,19.396 12.23975,18.5 13.34375,18.5 z" id="path9629" /> <path style="opacity:0.3;fill:url(#linearGradient9687);fill-opacity:1;fill-rule:evenodd;stroke:none" d="M 18.846598,24 L 8.028422,24 C 8.028422,26.76 10.451693,29 13.43751,29 C 16.423327,29 18.846598,26.76 18.846598,24 z" id="path9631" /> <path sodipodi:type="inkscape:offset" inkscape:radius="-0.77663463" inkscape:original="M 13.4375 16.5 C 9.5186162 16.499999 6.34375 19.657775 6.34375 23.5625 C 6.3437502 26.380698 7.9483759 28.863095 10.34375 30 L 10.34375 31.5 L 11.84375 33 L 10.34375 34.5 L 10.34375 35.5 L 12.34375 36.5 L 12.34375 37.5 L 10.34375 38.5 L 10.34375 39.5 L 11.84375 41 L 10.34375 42.5 L 10.34375 43.5 L 12.84375 45.5 L 15.34375 45.5 L 16.34375 44 L 16.34375 30 C 18.716179 28.854566 20.34375 26.301484 20.34375 23.5 C 20.34375 19.595276 17.356384 16.5 13.4375 16.5 z M 13.34375 18.5 C 14.44775 18.5 15.34375 19.396 15.34375 20.5 C 15.34375 21.604 14.44775 22.5 13.34375 22.5 C 12.23975 22.5 11.34375 21.604 11.34375 20.5 C 11.34375 19.396 12.23975 18.5 13.34375 18.5 z " xlink:href="#path1884" style="opacity:1;fill:none;stroke:#ffffff;stroke-width:0.79014969;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1" id="path9633" inkscape:href="#path1884" d="M 13.4375,17.28125 C 9.9358164,17.281249 7.125,20.078754 7.125,23.5625 C 7.1250002,26.085898 8.5663689,28.305758 10.6875,29.3125 C 10.951494,29.440624 11.120744,29.706589 11.125,30 L 11.125,31.15625 L 12.40625,32.4375 C 12.560213,32.584102 12.647354,32.787405 12.647354,33 C 12.647354,33.212595 12.560213,33.415898 12.40625,33.5625 L 11.125,34.84375 L 11.125,35.03125 L 12.6875,35.8125 C 12.951494,35.940624 13.120744,36.206589 13.125,36.5 L 13.125,37.5 C 13.120744,37.793411 12.951494,38.059376 12.6875,38.1875 L 11.125,38.96875 L 11.125,39.15625 L 12.40625,40.4375 C 12.560213,40.584102 12.647354,40.787405 12.647354,41 C 12.647354,41.212595 12.560213,41.415898 12.40625,41.5625 L 11.125,42.84375 L 11.125,43.125 L 13.125,44.71875 L 14.90625,44.71875 L 15.5625,43.75 L 15.5625,30 C 15.566756,29.706589 15.736006,29.440624 16,29.3125 C 18.090762,28.303058 19.5625,26.000684 19.5625,23.5 C 19.5625,19.991393 16.947441,17.28125 13.4375,17.28125 z M 13.34375,17.71875 C 14.867958,17.71875 16.125,18.975792 16.125,20.5 C 16.125,22.024208 14.867958,23.28125 13.34375,23.28125 C 11.819542,23.28125 10.5625,22.024208 10.5625,20.5 C 10.5625,18.975792 11.819542,17.71875 13.34375,17.71875 z" /> <path d="M 13.40625,17.625 C 13.187538,17.629341 12.939695,17.659156 12.71875,17.6875 C 11.78621,17.807129 10.942882,18.147772 10.1875,18.625 C 10.361143,19.259817 10.61214,19.783079 10.90625,20.25 C 11.032204,18.930646 12.148103,17.90625 13.5,17.90625 C 14.936081,17.90625 16.09375,19.063918 16.09375,20.5 C 16.09375,21.936083 14.936081,23.09375 13.5,23.09375 C 13.422832,23.09375 13.35303,23.07256 13.28125,23.0625 C 14.340561,24.332754 15.303193,26.006767 15.5625,29.15625 C 17.828737,28.247206 19.4375,26.230684 19.4375,23.5625 C 19.35195,20.960576 17.896038,18.951077 15.4375,17.9375 C 14.757352,17.712171 14.073888,17.611746 13.40625,17.625 z M 15.375,34.6875 C 15.095565,37.273086 14.520442,40.429504 13.5625,44.375 L 14.71875,44.375 L 15.375,43.0625 L 15.375,34.6875 z" id="path9635" style="opacity:0.6;fill:url(#linearGradient9689);fill-opacity:1;fill-rule:evenodd;stroke:none" inkscape:original="M 13.40625 17.53125 C 13.179953 17.535742 12.940048 17.565361 12.71875 17.59375 C 11.746507 17.718472 10.844502 18.056009 10.0625 18.5625 C 10.273788 19.382459 10.603512 20.028723 11 20.59375 C 10.998818 20.562191 11 20.531846 11 20.5 C 11 19.119998 12.119999 18 13.5 18 C 14.880001 18 16 19.119998 16 20.5 C 16 21.880003 14.880001 23 13.5 23 C 13.338115 23 13.184591 22.966937 13.03125 22.9375 C 14.159156 24.243071 15.219875 25.922289 15.46875 29.3125 C 17.839227 28.416828 19.53125 26.324417 19.53125 23.5625 C 19.444481 20.923505 17.958879 18.870351 15.46875 17.84375 C 14.777284 17.614671 14.085142 17.517773 13.40625 17.53125 z M 15.46875 31.96875 C 15.356466 34.978468 14.778907 38.970391 13.4375 44.46875 L 14.78125 44.46875 L 15.46875 43.125 L 15.46875 31.96875 z " inkscape:radius="-0.10364762" sodipodi:type="inkscape:offset" /> <rect style="opacity:0.61538463;fill:url(#linearGradient9691);fill-opacity:1;fill-rule:evenodd;stroke:none" id="rect9637" width="16.311773" height="0.98128641" x="29" y="-14.84375" transform="matrix(0,1,-1,0,0,0)" /> </g> <path id="path9639" d="M 14.3125,7.0625 C 13.227249,7.0873158 12.123399,7.3207085 11.0625,7.75 C 9.2695198,8.933921 7.864725,10.768315 7.25,13.0625 C 5.8984725,18.106464 8.8773006,23.277497 13.90625,24.625 C 17.195062,25.506234 20.530668,24.542893 22.84375,22.34375 L 22.5,21.75 C 24.309043,18.837555 24.440505,14.957047 22.625,11.8125 C 20.828263,8.7004584 17.618397,6.986906 14.3125,7.0625 z M 12.3125,11.28125 C 13.077267,11.185642 13.870722,11.538945 14.28125,12.25 C 14.560067,12.732925 14.609198,13.285658 14.46875,13.78125 C 14.647201,14.192491 14.687138,14.659846 14.5625,15.125 C 14.269235,16.21948 13.12573,16.887015 12.03125,16.59375 C 10.93677,16.300486 10.300485,15.15698 10.59375,14.0625 C 10.612621,13.992071 10.661924,13.941638 10.6875,13.875 C 10.68423,13.865214 10.690609,13.853563 10.6875,13.84375 C 10.413107,12.97776 10.742231,12.004833 11.5625,11.53125 C 11.799518,11.394408 12.057578,11.313119 12.3125,11.28125 z" style="opacity:0.10869565;fill:#000000;fill-opacity:1;fill-rule:evenodd;stroke:none" /> <g transform="matrix(0.3275569,-1.222459,1.222459,0.3275569,-16.853691,23.191962)" id="g9641"> <path sodipodi:nodetypes="csccccccccccccccccsccsssc" style="fill:url(#linearGradient9693);fill-opacity:1;fill-rule:evenodd;stroke:url(#linearGradient9695);stroke-width:0.79014969;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1" d="M 13.4375,16.5 C 9.5186162,16.499999 6.34375,19.657775 6.34375,23.5625 C 6.3437502,26.380698 7.9483759,28.863095 10.34375,30 L 10.34375,31.5 L 11.84375,33 L 10.34375,34.5 L 10.34375,35.5 L 12.34375,36.5 L 12.34375,37.5 L 10.34375,38.5 L 10.34375,39.5 L 11.84375,41 L 10.34375,42.5 L 10.34375,43.5 L 12.84375,45.5 L 15.34375,45.5 L 16.34375,44 L 16.34375,30 C 18.716179,28.854566 20.34375,26.301484 20.34375,23.5 C 20.34375,19.595276 17.356384,16.5 13.4375,16.5 z M 13.34375,18.5 C 14.44775,18.5 15.34375,19.396 15.34375,20.5 C 15.34375,21.604 14.44775,22.5 13.34375,22.5 C 12.23975,22.5 11.34375,21.604 11.34375,20.5 C 11.34375,19.396 12.23975,18.5 13.34375,18.5 z" id="path9643" /> <path style="opacity:0.3;fill:url(#linearGradient9697);fill-opacity:1;fill-rule:evenodd;stroke:none" d="M 18.846598,24 L 8.028422,24 C 8.028422,26.76 10.451693,29 13.43751,29 C 16.423327,29 18.846598,26.76 18.846598,24 z" id="path9645" /> <path sodipodi:type="inkscape:offset" inkscape:radius="-0.77663463" inkscape:original="M 13.4375 16.5 C 9.5186162 16.499999 6.34375 19.657775 6.34375 23.5625 C 6.3437502 26.380698 7.9483759 28.863095 10.34375 30 L 10.34375 31.5 L 11.84375 33 L 10.34375 34.5 L 10.34375 35.5 L 12.34375 36.5 L 12.34375 37.5 L 10.34375 38.5 L 10.34375 39.5 L 11.84375 41 L 10.34375 42.5 L 10.34375 43.5 L 12.84375 45.5 L 15.34375 45.5 L 16.34375 44 L 16.34375 30 C 18.716179 28.854566 20.34375 26.301484 20.34375 23.5 C 20.34375 19.595276 17.356384 16.5 13.4375 16.5 z M 13.34375 18.5 C 14.44775 18.5 15.34375 19.396 15.34375 20.5 C 15.34375 21.604 14.44775 22.5 13.34375 22.5 C 12.23975 22.5 11.34375 21.604 11.34375 20.5 C 11.34375 19.396 12.23975 18.5 13.34375 18.5 z " xlink:href="#path1884" style="opacity:1;fill:none;stroke:#ffffff;stroke-width:0.79014969;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1" id="path9647" inkscape:href="#path1884" d="M 13.4375,17.28125 C 9.9358164,17.281249 7.125,20.078754 7.125,23.5625 C 7.1250002,26.085898 8.5663689,28.305758 10.6875,29.3125 C 10.951494,29.440624 11.120744,29.706589 11.125,30 L 11.125,31.15625 L 12.40625,32.4375 C 12.560213,32.584102 12.647354,32.787405 12.647354,33 C 12.647354,33.212595 12.560213,33.415898 12.40625,33.5625 L 11.125,34.84375 L 11.125,35.03125 L 12.6875,35.8125 C 12.951494,35.940624 13.120744,36.206589 13.125,36.5 L 13.125,37.5 C 13.120744,37.793411 12.951494,38.059376 12.6875,38.1875 L 11.125,38.96875 L 11.125,39.15625 L 12.40625,40.4375 C 12.560213,40.584102 12.647354,40.787405 12.647354,41 C 12.647354,41.212595 12.560213,41.415898 12.40625,41.5625 L 11.125,42.84375 L 11.125,43.125 L 13.125,44.71875 L 14.90625,44.71875 L 15.5625,43.75 L 15.5625,30 C 15.566756,29.706589 15.736006,29.440624 16,29.3125 C 18.090762,28.303058 19.5625,26.000684 19.5625,23.5 C 19.5625,19.991393 16.947441,17.28125 13.4375,17.28125 z M 13.34375,17.71875 C 14.867958,17.71875 16.125,18.975792 16.125,20.5 C 16.125,22.024208 14.867958,23.28125 13.34375,23.28125 C 11.819542,23.28125 10.5625,22.024208 10.5625,20.5 C 10.5625,18.975792 11.819542,17.71875 13.34375,17.71875 z" /> <path d="M 13.40625,17.625 C 13.187538,17.629341 12.939695,17.659156 12.71875,17.6875 C 11.78621,17.807129 10.942882,18.147772 10.1875,18.625 C 10.361143,19.259817 10.61214,19.783079 10.90625,20.25 C 11.032204,18.930646 12.148103,17.90625 13.5,17.90625 C 14.936081,17.90625 16.09375,19.063918 16.09375,20.5 C 16.09375,21.936083 14.936081,23.09375 13.5,23.09375 C 13.422832,23.09375 13.35303,23.07256 13.28125,23.0625 C 14.340561,24.332754 15.303193,26.006767 15.5625,29.15625 C 17.828737,28.247206 19.4375,26.230684 19.4375,23.5625 C 19.35195,20.960576 17.896038,18.951077 15.4375,17.9375 C 14.757352,17.712171 14.073888,17.611746 13.40625,17.625 z M 15.375,34.6875 C 15.095565,37.273086 14.520442,40.429504 13.5625,44.375 L 14.71875,44.375 L 15.375,43.0625 L 15.375,34.6875 z" id="path9649" style="opacity:0.6;fill:url(#linearGradient9699);fill-opacity:1;fill-rule:evenodd;stroke:none" inkscape:original="M 13.40625 17.53125 C 13.179953 17.535742 12.940048 17.565361 12.71875 17.59375 C 11.746507 17.718472 10.844502 18.056009 10.0625 18.5625 C 10.273788 19.382459 10.603512 20.028723 11 20.59375 C 10.998818 20.562191 11 20.531846 11 20.5 C 11 19.119998 12.119999 18 13.5 18 C 14.880001 18 16 19.119998 16 20.5 C 16 21.880003 14.880001 23 13.5 23 C 13.338115 23 13.184591 22.966937 13.03125 22.9375 C 14.159156 24.243071 15.219875 25.922289 15.46875 29.3125 C 17.839227 28.416828 19.53125 26.324417 19.53125 23.5625 C 19.444481 20.923505 17.958879 18.870351 15.46875 17.84375 C 14.777284 17.614671 14.085142 17.517773 13.40625 17.53125 z M 15.46875 31.96875 C 15.356466 34.978468 14.778907 38.970391 13.4375 44.46875 L 14.78125 44.46875 L 15.46875 43.125 L 15.46875 31.96875 z " inkscape:radius="-0.10364762" sodipodi:type="inkscape:offset" /> <rect style="opacity:0.61538463;fill:url(#linearGradient9701);fill-opacity:1;fill-rule:evenodd;stroke:none" id="rect9651" width="16.311773" height="0.98128641" x="29" y="-14.84375" transform="matrix(0,1,-1,0,0,0)" /> </g> <path id="path9653" d="M 15.875,5.21875 C 11.900258,5.3327252 8.3470234,7.9683529 7.25,12.0625 C 7.1374957,12.482371 7.0851923,12.893096 7.03125,13.3125 C 7.0487991,14.044161 7.1437523,14.784849 7.34375,15.53125 C 8.6974648,20.583387 13.869054,23.599713 18.90625,22.25 C 22.408625,21.311541 24.99655,18.519035 25.75,15.1875 L 27.3125,14.75 C 27.442205,14.712249 27.560952,14.650188 27.625,14.53125 L 28.25,13.375 L 25.53125,12.65625 C 24.764566,9.3333908 22.146582,6.4977316 18.65625,5.5625 C 17.716152,5.3106016 16.792248,5.192448 15.875,5.21875 z M 12.6875,11.53125 C 12.823745,11.539323 12.98819,11.557092 13.125,11.59375 C 14.009003,11.830618 14.582988,12.630759 14.625,13.5 C 14.64717,13.559954 14.670587,13.62438 14.6875,13.6875 C 14.978559,14.773748 14.367498,15.865191 13.28125,16.15625 C 12.195002,16.447309 11.103559,15.804998 10.8125,14.71875 C 10.795944,14.656962 10.791925,14.592933 10.78125,14.53125 C 10.552473,14.090985 10.455671,13.577818 10.59375,13.0625 C 10.850357,12.10483 11.733788,11.474737 12.6875,11.53125 z" style="opacity:0.06086958;fill:#000000;fill-opacity:1;fill-rule:evenodd;stroke:none" /> <g transform="matrix(-0.3275569,-1.222459,1.222459,-0.3275569,-7.94356,36.230007)" id="g9655"> <path sodipodi:nodetypes="csccccccccccccccccsccsssc" style="fill:url(#linearGradient9703);fill-opacity:1;fill-rule:evenodd;stroke:url(#linearGradient9705);stroke-width:0.79014969;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1" d="M 13.4375,16.5 C 9.5186162,16.499999 6.34375,19.657775 6.34375,23.5625 C 6.3437502,26.380698 7.9483759,28.863095 10.34375,30 L 10.34375,31.5 L 11.84375,33 L 10.34375,34.5 L 10.34375,35.5 L 12.34375,36.5 L 12.34375,37.5 L 10.34375,38.5 L 10.34375,39.5 L 11.84375,41 L 10.34375,42.5 L 10.34375,43.5 L 12.84375,45.5 L 15.34375,45.5 L 16.34375,44 L 16.34375,30 C 18.716179,28.854566 20.34375,26.301484 20.34375,23.5 C 20.34375,19.595276 17.356384,16.5 13.4375,16.5 z M 13.34375,18.5 C 14.44775,18.5 15.34375,19.396 15.34375,20.5 C 15.34375,21.604 14.44775,22.5 13.34375,22.5 C 12.23975,22.5 11.34375,21.604 11.34375,20.5 C 11.34375,19.396 12.23975,18.5 13.34375,18.5 z" id="path9657" /> <path style="opacity:0.58260869;fill:url(#linearGradient9707);fill-opacity:1;fill-rule:evenodd;stroke:none" d="M 18.846598,24 L 8.028422,24 C 8.028422,26.76 10.451693,29 13.43751,29 C 16.423327,29 18.846598,26.76 18.846598,24 z" id="path9659" /> <path sodipodi:type="inkscape:offset" inkscape:radius="-0.77663463" inkscape:original="M 13.4375 16.5 C 9.5186162 16.499999 6.34375 19.657775 6.34375 23.5625 C 6.3437502 26.380698 7.9483759 28.863095 10.34375 30 L 10.34375 31.5 L 11.84375 33 L 10.34375 34.5 L 10.34375 35.5 L 12.34375 36.5 L 12.34375 37.5 L 10.34375 38.5 L 10.34375 39.5 L 11.84375 41 L 10.34375 42.5 L 10.34375 43.5 L 12.84375 45.5 L 15.34375 45.5 L 16.34375 44 L 16.34375 30 C 18.716179 28.854566 20.34375 26.301484 20.34375 23.5 C 20.34375 19.595276 17.356384 16.5 13.4375 16.5 z M 13.34375 18.5 C 14.44775 18.5 15.34375 19.396 15.34375 20.5 C 15.34375 21.604 14.44775 22.5 13.34375 22.5 C 12.23975 22.5 11.34375 21.604 11.34375 20.5 C 11.34375 19.396 12.23975 18.5 13.34375 18.5 z " xlink:href="#path1884" style="opacity:1;fill:none;stroke:#ffffff;stroke-width:0.79014969;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1" id="path9661" inkscape:href="#path1884" d="M 13.4375,17.28125 C 9.9358164,17.281249 7.125,20.078754 7.125,23.5625 C 7.1250002,26.085898 8.5663689,28.305758 10.6875,29.3125 C 10.951494,29.440624 11.120744,29.706589 11.125,30 L 11.125,31.15625 L 12.40625,32.4375 C 12.560213,32.584102 12.647354,32.787405 12.647354,33 C 12.647354,33.212595 12.560213,33.415898 12.40625,33.5625 L 11.125,34.84375 L 11.125,35.03125 L 12.6875,35.8125 C 12.951494,35.940624 13.120744,36.206589 13.125,36.5 L 13.125,37.5 C 13.120744,37.793411 12.951494,38.059376 12.6875,38.1875 L 11.125,38.96875 L 11.125,39.15625 L 12.40625,40.4375 C 12.560213,40.584102 12.647354,40.787405 12.647354,41 C 12.647354,41.212595 12.560213,41.415898 12.40625,41.5625 L 11.125,42.84375 L 11.125,43.125 L 13.125,44.71875 L 14.90625,44.71875 L 15.5625,43.75 L 15.5625,30 C 15.566756,29.706589 15.736006,29.440624 16,29.3125 C 18.090762,28.303058 19.5625,26.000684 19.5625,23.5 C 19.5625,19.991393 16.947441,17.28125 13.4375,17.28125 z M 13.34375,17.71875 C 14.867958,17.71875 16.125,18.975792 16.125,20.5 C 16.125,22.024208 14.867958,23.28125 13.34375,23.28125 C 11.819542,23.28125 10.5625,22.024208 10.5625,20.5 C 10.5625,18.975792 11.819542,17.71875 13.34375,17.71875 z" /> <path d="M 13.40625,17.625 C 13.187538,17.629341 12.939695,17.659156 12.71875,17.6875 C 11.78621,17.807129 10.942882,18.147772 10.1875,18.625 C 10.361143,19.259817 10.61214,19.783079 10.90625,20.25 C 11.032204,18.930646 12.148103,17.90625 13.5,17.90625 C 14.936081,17.90625 16.09375,19.063918 16.09375,20.5 C 16.09375,21.936083 14.936081,23.09375 13.5,23.09375 C 13.422832,23.09375 13.35303,23.07256 13.28125,23.0625 C 14.340561,24.332754 15.303193,26.006767 15.5625,29.15625 C 17.828737,28.247206 19.4375,26.230684 19.4375,23.5625 C 19.35195,20.960576 17.896038,18.951077 15.4375,17.9375 C 14.757352,17.712171 14.073888,17.611746 13.40625,17.625 z M 15.375,34.6875 C 15.095565,37.273086 14.520442,40.429504 13.5625,44.375 L 14.71875,44.375 L 15.375,43.0625 L 15.375,34.6875 z" id="path9663" style="opacity:0.6;fill:url(#linearGradient9709);fill-opacity:1;fill-rule:evenodd;stroke:none" inkscape:original="M 13.40625 17.53125 C 13.179953 17.535742 12.940048 17.565361 12.71875 17.59375 C 11.746507 17.718472 10.844502 18.056009 10.0625 18.5625 C 10.273788 19.382459 10.603512 20.028723 11 20.59375 C 10.998818 20.562191 11 20.531846 11 20.5 C 11 19.119998 12.119999 18 13.5 18 C 14.880001 18 16 19.119998 16 20.5 C 16 21.880003 14.880001 23 13.5 23 C 13.338115 23 13.184591 22.966937 13.03125 22.9375 C 14.159156 24.243071 15.219875 25.922289 15.46875 29.3125 C 17.839227 28.416828 19.53125 26.324417 19.53125 23.5625 C 19.444481 20.923505 17.958879 18.870351 15.46875 17.84375 C 14.777284 17.614671 14.085142 17.517773 13.40625 17.53125 z M 15.46875 31.96875 C 15.356466 34.978468 14.778907 38.970391 13.4375 44.46875 L 14.78125 44.46875 L 15.46875 43.125 L 15.46875 31.96875 z " inkscape:radius="-0.10364762" sodipodi:type="inkscape:offset" /> <rect style="opacity:0.61538463;fill:url(#linearGradient9711);fill-opacity:1;fill-rule:evenodd;stroke:none" id="rect9665" width="16.311773" height="0.98128641" x="29" y="-14.84375" transform="matrix(0,1,-1,0,0,0)" /> </g> <path style="fill:none;stroke:url(#radialGradient9713);stroke-width:3;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dashoffset:0.69999992;stroke-opacity:1" d="M 4.8047213,30.320897 C 2.2105973,31.911021 1.3846493,29.381868 2.9610893,24.675465 C 4.5375293,19.969062 7.9223353,14.858836 10.51646,13.268712 C 11.803703,12.479669 12.629423,12.625146 12.995199,13.705422" id="path9667" /> <path sodipodi:type="arc" style="fill:url(#radialGradient9715);fill-opacity:1;fill-rule:evenodd;stroke:none;marker:none;marker-start:none;marker-mid:none;marker-end:none;visibility:visible;display:inline;overflow:visible;enable-background:accumulate" id="path9669" sodipodi:cx="11.15625" sodipodi:cy="2.0625" sodipodi:rx="0.90625" sodipodi:ry="0.5625" d="M 12.0625,2.0625 A 0.90625,0.5625 0 1 1 10.25,2.0625 A 0.90625,0.5625 0 1 1 12.0625,2.0625 z" transform="matrix(0,-1.5911082,2.563452,0,-2.9276547,44.523509)" /> <path style="fill:none;stroke:url(#radialGradient9717);stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dashoffset:0.69999992;stroke-opacity:1" d="M 7.7427353,27.481458 C 4.7075103,31.331809 2.2073393,31.90911 2.1619953,28.770077 C 2.1166513,25.631044 4.5432213,19.958501 7.5784463,16.108151 C 10.567389,12.31651 13.039419,11.685867 13.155641,14.685343" id="path9671" /> <path style="opacity:0.10407242;fill:none;stroke:url(#linearGradient9719);stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dashoffset:0.69999992;stroke-opacity:1" d="M 7.5779723,16.108752 C 10.567078,12.316634 13.039412,11.6857 13.155641,14.685343" id="path9673" sodipodi:nodetypes="cc" /> <path sodipodi:type="arc" style="fill:#ffffff;fill-opacity:1;fill-rule:evenodd;stroke:none;marker:none;marker-start:none;marker-mid:none;marker-end:none;visibility:visible;display:inline;overflow:visible;enable-background:accumulate" id="path9675" sodipodi:cx="11.15625" sodipodi:cy="2.0625" sodipodi:rx="0.90625" sodipodi:ry="0.5625" d="M 12.0625,2.0625 A 0.90625,0.5625 0 1 1 10.25,2.0625 A 0.90625,0.5625 0 1 1 12.0625,2.0625 z" transform="matrix(0,-1.1034483,1.7777778,0,-1.2851047,38.994666)" /> </g> </g> </svg>


@@ pic/home.svg
<?xml version="1.0" encoding="UTF-8" standalone="no"?> <!-- Created with Inkscape (http://www.inkscape.org/) --> <svg xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:cc="http://creativecommons.org/ns#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" width="48px" height="48px" id="svg8433" sodipodi:version="0.32" inkscape:version="0.46" sodipodi:docname="drawing.svg" inkscape:output_extension="org.inkscape.output.svg.inkscape"> <defs id="defs8435"> <linearGradient id="linearGradient3991"> <stop style="stop-color:#a40000;stop-opacity:1" offset="0" id="stop3993" /> <stop style="stop-color:#c00;stop-opacity:1" offset="1" id="stop3995" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3991" id="linearGradient3819" gradientUnits="userSpaceOnUse" gradientTransform="translate(0,3)" x1="133.37802" y1="56.529476" x2="133.37802" y2="54.847771" /> <linearGradient id="linearGradient4022"> <stop id="stop4024" offset="0" style="stop-color:#ef2929;stop-opacity:1" /> <stop id="stop4026" offset="1" style="stop-color:#e9b96e;stop-opacity:1;" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient4022" id="linearGradient3815" gradientUnits="userSpaceOnUse" gradientTransform="translate(0,3)" x1="136.93753" y1="54.646889" x2="135.61183" y2="54.646889" /> <linearGradient id="linearGradient4078"> <stop style="stop-color:black;stop-opacity:1;" offset="0" id="stop4080" /> <stop style="stop-color:black;stop-opacity:0;" offset="1" id="stop4082" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient4078" id="linearGradient3813" gradientUnits="userSpaceOnUse" gradientTransform="translate(0,3.25)" x1="136.15625" y1="53.605896" x2="136.625" y2="57.073547" /> <linearGradient inkscape:collect="always" id="linearGradient4028"> <stop style="stop-color:#888a85;stop-opacity:1;" offset="0" id="stop4030" /> <stop style="stop-color:#555753;stop-opacity:1" offset="1" id="stop4032" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient4028" id="linearGradient3811" gradientUnits="userSpaceOnUse" gradientTransform="translate(0,1)" x1="137.96875" y1="63.281586" x2="137.96875" y2="57.468296" /> <linearGradient id="linearGradient4048"> <stop id="stop4050" offset="0" style="stop-color:#d3d7cf;stop-opacity:1" /> <stop id="stop4052" offset="1" style="stop-color:white;stop-opacity:1;" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient4048" id="linearGradient3809" gradientUnits="userSpaceOnUse" gradientTransform="translate(0,1)" x1="135.6875" y1="58.0625" x2="136.64372" y2="61.4375" /> <linearGradient inkscape:collect="always" id="linearGradient3817"> <stop style="stop-color:white;stop-opacity:1;" offset="0" id="stop3819" /> <stop style="stop-color:white;stop-opacity:0;" offset="1" id="stop3821" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3817" id="linearGradient3807" gradientUnits="userSpaceOnUse" x1="114.10936" y1="50.828426" x2="135.7645" y2="77.6101" /> <linearGradient inkscape:collect="always" id="linearGradient3848"> <stop style="stop-color:#ef2929;stop-opacity:1;" offset="0" id="stop3850" /> <stop style="stop-color:#c00;stop-opacity:1" offset="1" id="stop3852" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3848" id="linearGradient3805" gradientUnits="userSpaceOnUse" gradientTransform="translate(0,1)" x1="128.74188" y1="60.433819" x2="146.7552" y2="56.357101" /> <linearGradient id="linearGradient3239"> <stop style="stop-color:#ef2929;stop-opacity:1;" offset="0" id="stop3241" /> <stop style="stop-color:#f89797;stop-opacity:1;" offset="1" id="stop3243" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3239" id="linearGradient3803" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1.949012,0,0,1.946639,-14.36421,-5.33889)" x1="64.905609" y1="31.427" x2="71.622536" y2="35.981598" /> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3875" id="linearGradient3801" gradientUnits="userSpaceOnUse" x1="123.00044" y1="62.068974" x2="124" y2="64.431534" /> <linearGradient inkscape:collect="always" id="linearGradient3875"> <stop style="stop-color:black;stop-opacity:1;" offset="0" id="stop3877" /> <stop style="stop-color:black;stop-opacity:0;" offset="1" id="stop3879" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3875" id="linearGradient3799" gradientUnits="userSpaceOnUse" x1="124.79935" y1="62" x2="124" y2="64.369034" /> <linearGradient id="linearGradient2712"> <stop id="stop2714" offset="0" style="stop-color:#729fcf;stop-opacity:1" /> <stop id="stop2716" offset="1" style="stop-color:white;stop-opacity:1" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient2712" id="linearGradient3796" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0.750006,0,0,0.749999,65.6246,46.87498)" x1="69.166649" y1="35.443001" x2="69.166649" y2="57.718136" /> <linearGradient id="linearGradient3217"> <stop style="stop-color:#c17d11;stop-opacity:1;" offset="0" id="stop3219" /> <stop style="stop-color:#8f5902;stop-opacity:1" offset="1" id="stop3221" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3217" id="linearGradient3792" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1.60001,0,0,1.55556,11.4993,11.49992)" x1="75.739166" y1="48.240158" x2="74.236351" y2="46.286785" /> <linearGradient id="linearGradient3209"> <stop style="stop-color:#c17d11;stop-opacity:1" offset="0" id="stop3211" /> <stop style="stop-color:#e9b96e;stop-opacity:1;" offset="1" id="stop3213" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3209" id="linearGradient3790" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1.60001,0,0,1.55556,11.4993,11.49992)" x1="73.90403" y1="41.016624" x2="76.84375" y2="47.218826" /> <linearGradient id="linearGradient3914"> <stop style="stop-color:#555753;stop-opacity:1;" offset="0" id="stop3916" /> <stop style="stop-color:#888a85;stop-opacity:1" offset="1" id="stop3918" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3914" id="linearGradient3788" gradientUnits="userSpaceOnUse" x1="125.59375" y1="92.15625" x2="125.59375" y2="88.46875" /> <linearGradient inkscape:collect="always" id="linearGradient3896"> <stop style="stop-color:#888a85;stop-opacity:1" offset="0" id="stop3898" /> <stop style="stop-color:#eeeeec;stop-opacity:0" offset="1" id="stop3900" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3896" id="linearGradient3786" gradientUnits="userSpaceOnUse" x1="124.3624" y1="91.663841" x2="137.75323" y2="92.636116" /> <linearGradient inkscape:collect="always" id="linearGradient3798"> <stop style="stop-color:white;stop-opacity:1;" offset="0" id="stop3800" /> <stop style="stop-color:white;stop-opacity:0;" offset="1" id="stop3802" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3798" id="linearGradient3784" gradientUnits="userSpaceOnUse" x1="108.875" y1="81.767754" x2="108.875" y2="57.59375" /> <linearGradient inkscape:collect="always" id="linearGradient3975"> <stop style="stop-color:black;stop-opacity:1;" offset="0" id="stop3977" /> <stop style="stop-color:black;stop-opacity:0;" offset="1" id="stop3979" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3975" id="linearGradient3782" gradientUnits="userSpaceOnUse" x1="129" y1="73.9375" x2="129" y2="88.440292" /> <linearGradient inkscape:collect="always" id="linearGradient8087"> <stop style="stop-color:#555753;stop-opacity:1;" offset="0" id="stop8089" /> <stop style="stop-color:#888a85;stop-opacity:1" offset="1" id="stop8091" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient8087" id="linearGradient8093" x1="124" y1="73" x2="124" y2="97.894295" gradientUnits="userSpaceOnUse" /> <linearGradient id="linearGradient2541"> <stop id="stop2543" offset="0" style="stop-color:#babdb6;stop-opacity:1" /> <stop id="stop2545" offset="1" style="stop-color:#eeeeec;stop-opacity:1" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient2541" id="linearGradient3778" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1.949012,0,0,1.946639,-14.36421,-6.33889)" x1="71" y1="35.186462" x2="71.998184" y2="49.605785" /> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3703" id="linearGradient7661" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1.179548,0,0,1,-4.219389,0)" x1="17.554192" y1="46.000275" x2="17.554192" y2="34.999718" /> <radialGradient inkscape:collect="always" xlink:href="#linearGradient3681" id="radialGradient7659" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0.99001,0,0,1.1,-14.88523,-86.15)" cx="5" cy="41.5" fx="5" fy="41.5" r="5" /> <radialGradient inkscape:collect="always" xlink:href="#linearGradient3681" id="radialGradient7657" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0.990017,0,0,1.1,32.1147,-5.15)" cx="5" cy="41.5" fx="5" fy="41.5" r="5" /> <linearGradient id="linearGradient3703"> <stop style="stop-color:black;stop-opacity:0;" offset="0" id="stop3705" /> <stop id="stop3711" offset="0.5" style="stop-color:black;stop-opacity:1;" /> <stop style="stop-color:black;stop-opacity:0;" offset="1" id="stop3707" /> </linearGradient> <linearGradient inkscape:collect="always" xlink:href="#linearGradient3703" id="linearGradient7647" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1.179548,0,0,1,-4.219389,0)" x1="17.554192" y1="46.000275" x2="17.554192" y2="34.999718" /> <radialGradient inkscape:collect="always" xlink:href="#linearGradient3681" id="radialGradient7645" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0.99001,0,0,1.1,-14.88523,-86.15)" cx="5" cy="41.5" fx="5" fy="41.5" r="5" /> <linearGradient inkscape:collect="always" id="linearGradient3681"> <stop style="stop-color:black;stop-opacity:1;" offset="0" id="stop3683" /> <stop style="stop-color:black;stop-opacity:0;" offset="1" id="stop3685" /> </linearGradient> <radialGradient inkscape:collect="always" xlink:href="#linearGradient3681" id="radialGradient7643" gradientUnits="userSpaceOnUse" gradientTransform="matrix(0.990017,0,0,1.1,32.1147,-5.15)" cx="5" cy="41.5" fx="5" fy="41.5" r="5" /> </defs> <sodipodi:namedview id="base" pagecolor="#ffffff" bordercolor="#666666" borderopacity="1.0" inkscape:pageopacity="0.0" inkscape:pageshadow="2" inkscape:zoom="7" inkscape:cx="24" inkscape:cy="24" inkscape:current-layer="layer1" showgrid="true" inkscape:grid-bbox="true" inkscape:document-units="px" inkscape:window-width="641" inkscape:window-height="688" inkscape:window-x="331" inkscape:window-y="333" /> <metadata id="metadata8438"> <rdf:RDF> <cc:Work rdf:about=""> <dc:format>image/svg+xml</dc:format> <dc:type rdf:resource="http://purl.org/dc/dcmitype/StillImage" /> </cc:Work> </rdf:RDF> </metadata> <g id="layer1" inkscape:label="Layer 1" inkscape:groupmode="layer"> <g id="g3713" transform="matrix(0.4054054,0,0,0.2727273,21.972973,31.454544)" style="opacity:0.3;display:inline"> <rect y="35" x="37.064781" height="11" width="4.9352183" id="rect1907" style="opacity:1;fill:url(#radialGradient7643);fill-opacity:1;stroke:none;stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1" /> <rect transform="scale(-1,-1)" y="-46" x="-9.9351835" height="11" width="4.9351835" id="rect3689" style="opacity:1;fill:url(#radialGradient7645);fill-opacity:1;stroke:none;stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1" /> <rect y="35" x="9.9351835" height="11" width="27.129599" id="rect3693" style="opacity:1;fill:url(#linearGradient7647);fill-opacity:1;stroke:none;stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1" /> </g> <g id="g7649" transform="matrix(0.972973,0,0,0.5454545,1.135135,17.909092)" style="opacity:0.4;display:inline"> <rect y="35" x="37.064781" height="11" width="4.9352183" id="rect7651" style="opacity:1;fill:url(#radialGradient7657);fill-opacity:1;stroke:none;stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1" /> <rect transform="scale(-1,-1)" y="-46" x="-9.9351835" height="11" width="4.9351835" id="rect7653" style="opacity:1;fill:url(#radialGradient7659);fill-opacity:1;stroke:none;stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1" /> <rect y="35" x="9.9351835" height="11" width="27.129599" id="rect7655" style="opacity:1;fill:url(#linearGradient7661);fill-opacity:1;stroke:none;stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1" /> </g> <g style="display:inline" id="g3643" inkscape:export-filename="/home/lapo/Icone/Crux/navx.png" inkscape:export-xdpi="90" inkscape:export-ydpi="90" transform="translate(-100,-50.000001)"> <g transform="matrix(1.022059,0,0,1.157314,-2.735294,-14.1421)" style="opacity:0.4" id="g4120" /> <path inkscape:export-ydpi="90" inkscape:export-xdpi="90" inkscape:export-filename="/home/lapo/Icone/Crux/arrowx.png" sodipodi:nodetypes="cccccc" id="path3629" d="M 107.44904,67.633392 L 124.01564,60.820155 L 140.58224,67.633392 L 139.5,90.5 L 108.5,90.5 L 107.44904,67.633392 z" style="fill:url(#linearGradient3778);fill-opacity:1;stroke:url(#linearGradient8093);stroke-width:1;stroke-linecap:round;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" /> <rect inkscape:export-ydpi="90" inkscape:export-xdpi="90" inkscape:export-filename="/home/lapo/Icone/Crux/arrowx.png" y="73" x="126.00002" height="16" width="10.999982" id="rect3969" style="opacity:0.2;fill:url(#linearGradient3782);fill-opacity:1;stroke:none;stroke-width:1.00000095;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" /> <path sodipodi:nodetypes="cccccc" id="path3791" d="M 124.03125,60.90625 L 108.46875,68.28125 L 109.46875,89.5 L 138.53125,89.5 L 139.5625,68.28125 L 124.03125,60.90625 z" style="opacity:0.3;fill:none;fill-opacity:1;stroke:url(#linearGradient3784);stroke-width:1;stroke-linecap:round;stroke-linejoin:round;stroke-miterlimit:4;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" /> <path sodipodi:nodetypes="ccccccc" id="rect3635" d="M 126,88.5 L 137,88.5 L 137.5,90 L 137.49997,92.499953 L 125.51985,92.499953 L 125.51985,90.015617 L 126,88.5 z" style="fill:url(#linearGradient3786);fill-opacity:1;stroke:url(#linearGradient3788);stroke-width:1;stroke-linecap:square;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" /> <rect inkscape:export-ydpi="90" inkscape:export-xdpi="90" inkscape:export-filename="/home/lapo/Icone/Crux/arrowx.png" y="74.500023" x="127.50003" height="14.000022" width="8.0000248" id="rect3639" style="fill:url(#linearGradient3790);fill-opacity:1;stroke:url(#linearGradient3792);stroke-width:1.00000131;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" /> <path transform="matrix(1.6,0,0,1.641039,-79.75,-51.93698)" d="M 133.59375,81.921875 A 0.625,0.609375 0 1 1 132.34375,81.921875 A 0.625,0.609375 0 1 1 133.59375,81.921875 z" sodipodi:ry="0.609375" sodipodi:rx="0.625" sodipodi:cy="81.921875" sodipodi:cx="132.96875" id="path3773" style="opacity:0.3;fill:#000000;fill-opacity:1;fill-rule:nonzero;stroke:none;stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" sodipodi:type="arc" /> <path style="fill:none;fill-opacity:1;stroke:#eeeeec;stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" d="M 112.5,72.5 L 122.5,72.5 L 122.5,82.5 L 112.5,82.5 L 112.5,72.5 z" id="rect3641" sodipodi:nodetypes="ccccc" /> <path style="fill:#ffffff;fill-opacity:1;stroke:#ffffff;stroke-width:0.99999899;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" d="M 113.5,73.5 L 121.5029,73.505104 L 121.5029,81.475369 L 113.49998,81.475369 L 113.5,73.5 z" id="rect3682" sodipodi:nodetypes="ccccc" /> <path id="rect3722" d="M 114,74 L 114,77 L 117,77 L 117,74 L 114,74 z M 118,74 L 118,77 L 121,77 L 121,74 L 118,74 z M 114,78 L 114,81 L 117,81 L 117,78 L 114,78 z M 118,78 L 118,81 L 121,81 L 121,78 L 118,78 z" style="fill:url(#linearGradient3796);fill-opacity:1;stroke:none;stroke-width:0.99999893;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" /> <path sodipodi:nodetypes="ccccc" id="path3767" d="M 114,74 L 114,77 L 114.38128,74.39233 L 117,74 L 114,74 z" style="opacity:0.15;fill:#000000;fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1px;stroke-linecap:square;stroke-linejoin:miter;stroke-opacity:1;display:inline" /> <path transform="matrix(1.6,0,0,1.641039,-79.75,-52.43696)" d="M 133.59375,81.921875 A 0.625,0.609375 0 1 1 132.34375,81.921875 A 0.625,0.609375 0 1 1 133.59375,81.921875 z" sodipodi:ry="0.609375" sodipodi:rx="0.625" sodipodi:cy="81.921875" sodipodi:cx="132.96875" id="path3769" style="fill:#fce94f;fill-opacity:1;fill-rule:nonzero;stroke:none;stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" sodipodi:type="arc" /> <path transform="matrix(0.825,0,0,0.84616,23.09765,12.44659)" d="M 133.59375,81.921875 A 0.625,0.609375 0 1 1 132.34375,81.921875 A 0.625,0.609375 0 1 1 133.59375,81.921875 z" sodipodi:ry="0.609375" sodipodi:rx="0.625" sodipodi:cy="81.921875" sodipodi:cx="132.96875" id="path3771" style="fill:#ffffff;fill-opacity:1;fill-rule:nonzero;stroke:none;stroke-width:1;stroke-linecap:round;stroke-linejoin:miter;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" sodipodi:type="arc" /> <path sodipodi:nodetypes="ccccc" id="path3781" d="M 118,74 L 118,77 L 118.38128,74.39233 L 121,74 L 118,74 z" style="opacity:0.15;fill:#000000;fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1px;stroke-linecap:square;stroke-linejoin:miter;stroke-opacity:1;display:inline" /> <path sodipodi:nodetypes="ccccc" id="path3783" d="M 114,78 L 114,81 L 114.38128,78.39233 L 117,78 L 114,78 z" style="opacity:0.15;fill:#000000;fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1px;stroke-linecap:square;stroke-linejoin:miter;stroke-opacity:1;display:inline" /> <path sodipodi:nodetypes="ccccc" id="path3785" d="M 118,78 L 118,81 L 118.38128,78.39233 L 121,78 L 118,78 z" style="opacity:0.15;fill:#000000;fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1px;stroke-linecap:square;stroke-linejoin:miter;stroke-opacity:1;display:inline" /> <path sodipodi:nodetypes="ccccccccc" id="path3926" d="M 126.375,89 L 126.03125,90 L 126.03125,90.0625 L 126.03125,90.5 L 137,90.5 L 137,90.0625 L 137,90 L 136.65625,89 L 126.375,89 z" style="fill:#eeeeec;fill-opacity:1;stroke:none;stroke-width:1;stroke-linecap:square;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" /> <rect ry="0" rx="0" inkscape:export-ydpi="90" inkscape:export-xdpi="90" inkscape:export-filename="/home/lapo/Icone/Crux/arrowx.png" y="90" x="126" height="1" width="11" id="rect3886" style="fill:#ffffff;fill-opacity:1;stroke:none;stroke-width:0.99999982;stroke-linecap:square;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" /> <g transform="translate(0,-1)" id="g3616"> <g id="g3609" style="opacity:0.3" transform="translate(0,1)"> <path id="path3593" d="M 124,61.3125 L 124,64.4375 L 139.90625,71.8125 L 140.09375,67.9375 L 124.03125,61.3125 L 124,61.3125 z" style="opacity:1;fill:url(#linearGradient3799);fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:round;stroke-opacity:1;display:inline" /> <path id="path3856" d="M 124,61.3125 L 107.9375,67.9375 L 108.125,71.78125 L 124,64.4375 L 124,61.3125 z" style="opacity:1;fill:url(#linearGradient3801);fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:round;stroke-opacity:1;display:inline" /> </g> <path style="fill:url(#linearGradient3803);fill-opacity:1;fill-rule:evenodd;stroke:#a40000;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:round;stroke-opacity:1;display:inline" d="M 143.53125,71.55335 L 124,62.5 L 104.5,71.5 L 105.5,63.5 L 124,54.5 L 142.5,63.5 L 143.53125,71.55335" id="path3637" sodipodi:nodetypes="ccccccc" inkscape:export-filename="/home/lapo/Icone/Crux/arrowx.png" inkscape:export-xdpi="90" inkscape:export-ydpi="90" /> <path style="fill:url(#linearGradient3805);fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:round;stroke-opacity:1;display:inline" d="M 124,55.03125 L 124,62 C 124.07492,62 124.14984,62.028312 124.21875,62.0625 L 142.90625,70.75 L 142.03125,63.8125 L 124,55.03125 z" id="path3832" /> <path sodipodi:type="inkscape:offset" inkscape:radius="-1.0397406" inkscape:original="M 124 53.5 L 105.5 62.5 L 104.5 70.5 L 124 61.5 L 143.53125 70.5625 L 142.5 62.5 L 124 53.5 z " style="opacity:0.5;fill:none;fill-opacity:1;fill-rule:evenodd;stroke:url(#linearGradient3807);stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1;display:inline" id="path3812" d="M 124,54.65625 L 106.46875,63.1875 L 105.75,68.78125 L 123.5625,60.5625 C 123.83997,60.433813 124.16003,60.433813 124.4375,60.5625 L 142.25,68.84375 L 141.53125,63.1875 L 124,54.65625 z" transform="translate(0,1)" /> <path style="fill:url(#linearGradient3809);fill-opacity:1;stroke:url(#linearGradient3811);stroke-width:1.00000072;stroke-linecap:square;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" d="M 134.50006,57.542753 L 138.50011,57.542753 L 139.00834,64.088405 L 134.27909,61.752557 L 134.50006,57.542753 z" id="path3655" sodipodi:nodetypes="ccccc" inkscape:export-filename="/home/lapo/Icone/Crux/arrowx.png" inkscape:export-xdpi="90" inkscape:export-ydpi="90" /> <path style="fill:#eeeeec;fill-opacity:1;stroke:#a40000;stroke-width:1.00000024;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" d="M 139.75297,64.514386 L 133.48624,61.363324" id="path3657" sodipodi:nodetypes="cc" inkscape:export-filename="/home/lapo/Icone/Crux/arrowx.png" inkscape:export-xdpi="90" inkscape:export-ydpi="90" /> <path style="opacity:0.6;fill:none;fill-opacity:1;stroke:#ffffff;stroke-width:1.00000072;stroke-linecap:square;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dashoffset:1.20000057;stroke-opacity:1;display:inline" d="M 135.4375,57.96875 L 135.28125,61.15625 L 137.9375,62.46875 L 137.59375,57.96875 L 135.4375,57.96875 z" id="path4042" sodipodi:nodetypes="ccccc" /> <path sodipodi:nodetypes="ccccccc" style="fill:url(#linearGradient3813);fill-opacity:1;fill-rule:nonzero;stroke:none;stroke-width:1.00000012;stroke-linecap:square;stroke-linejoin:round;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:4;stroke-dashoffset:1.20000057;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" d="M 136.5,57.25 L 133.9375,59.09375 L 133.84375,60.640625 L 136.5,59.375 L 139.21875,60.671875 L 139.09375,59.125 L 136.5,57.25 z" id="path4055" /> <path style="fill:url(#linearGradient3815);fill-opacity:1;fill-rule:nonzero;stroke:url(#linearGradient3819);stroke-width:1.00000012;stroke-linecap:square;stroke-linejoin:round;marker:none;marker-start:none;marker-mid:none;marker-end:none;stroke-miterlimit:4;stroke-dashoffset:1.20000057;stroke-opacity:1;visibility:visible;display:inline;overflow:visible" d="M 133.50003,57.500004 L 136.50003,55.500004 L 139.50003,57.500004 L 139.50003,59.500004 L 136.50003,58.000004 L 133.50003,59.500004 L 133.50003,57.500004 z" id="rect4017" sodipodi:nodetypes="ccccccc" /> </g> </g> </g> </svg>


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

=head1 Using

  perl ./gitty.pl

Runs HTTP daemon on 3000 port.

=cut
