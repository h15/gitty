package Gitty;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
    my $app = shift;
    
    # Plugins
    $app->plugin('i18n');
    $app->plugin('message');
    $app->plugin('captcha');
    
    #
    #   Config is here
    #
    $app->plugin( sql => {
        host    => 'dbi:mysql:gitty',
        user    => 'gitty',
        passwd  => 'password',
        prefix  => 'gitty__',
    });
    $app->plugin( user => {
        cookies => 'some random string',    # random string for cookie salt;
        confirm => 7,                       # time to live of session in days;
        salt    => 'some random string',    # random string for db salt;
    });
    $app->plugin( mail => {
        site => 'http://lorcode.org:3000/',
        from => 'no-reply@lorcode.org'
    });
    $app->plugin( gitosis => {
        git_home => '/home/h15/gitosis/gitosis-admin/'
    });
    #
    #   End of config
    #
    
    # Routes
    my $r = $app->routes;
    $r->route('/')->via('get')->to(cb => sub { shift->render( template => 'info/index' ) })->name('index');
    
    # Help info
    $r = $app->routes->route('/help/git');
    $r->route('/install_gitosis')->via('get')
        ->to(cb => sub { shift->render( template => 'info/git/install_gitosis' ) })->name('install_gitosis');
    $r->route('/init')->via('get')->to(cb => sub { shift->render( template => 'info/git/init' ) })
        ->name('git_init');
    
    # Helpers
    $app->helper (
    	# Recursive build html tables for config structure.
        html_hash_tree => sub {
            my ( $self, $config, $parent ) = @_;
            my $ret = '';
            $parent ||= '';
            $config = {} unless defined %$config;
            
            for my $k ( keys %$config ) {
                $ret .= "<tr><td>$k</td><td name='$parent-$k'>";
                
                # Branch or leaf?
                $ret .= ( ref $config->{$k} ?
                    $self->html_hash_tree( $config->{$k}, "$parent-$k" ) :
                    "<input value='" . $config->{$k} . "' name='$parent-$k-input'>"
                );
                $ret .= "</td></tr>";
            }
            return "<table>$ret</table>";
        }
    );
    
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

package Gitty::I18N::ru;
use base 'Gitty::I18N';

use Encode 'decode';

our %Lexicon = (
    _AUTO => 1,
    'Repo'          => 'Репозиторий',
    'New repo'      => 'Создать новый',
    'Add key'       => 'Добавить ключ',
    'name'          => 'имя',
    'members'       => 'пользователи',
    'description'   => 'описание',
    'password'      => 'пароль',
    'repeat'        => 'повторить',
    'registered'    => 'зарегистрирован',
    'ban reason'    => 'причина блокировки',
    'ban time'      => 'время блокировки',
    'now'           => 'сейчас',
    'Add'           => 'Добавить',
    'status'        => 'статус',
    'active'        => 'активный',
    'inactive'      => 'деактивирован',
    'week'          => 'неделя',
    'day'           => 'день',
    'hour'          => 'час',
    
    'mins1'         => 'минуту',
    'mins2'         => 'минуты',
    'mins5'         => 'минут',
    
    'hours1'        => 'час',
    'hours2'        => 'часа',
    'hours5'        => 'часов',
    
    'ago'           => 'назад',
    
    'a few seconds ago' => 'несколько секунд назад',
    'Your public key'   => 'Ваш публичный ключ',
    'Create new repo'   => 'Создать новый репозиторий',
    'Repository list'   => 'Список репозиториев',
    'change password'   => 'сменить пароль',
    'How to create new repository' => 'Как создать новый репозиторий',
);

$Lexicon{$_} = decode('utf8', $Lexicon{$_}) for keys %Lexicon;

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

