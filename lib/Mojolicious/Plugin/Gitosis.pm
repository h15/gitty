package Mojolicious::Plugin::Gitosis;
use Mojo::Base 'Mojolicious::Plugin';

use Mojolicious::Plugin::Gitosis::EasyConfig;

sub register {
    my ( $self, $app ) = @_;
    
    unless( $app->config('gitosis') )
    {
        $app->config ( gitosis => {
            git_home => '/home/user/gitosis-admin/',
            allow_empty_description => 0,
            group_is_repo => 1,
        });
    }
    
    my $conf = $app->config('gitosis');
    
    my $git_conf = new Mojolicious::Plugin::Gitosis::EasyConfig({
        file => $conf->{git_home} . 'gitosis.conf'
    });
    
    $app->helper( gitosis => sub{ $git_conf } );
    
    # Routes
    my $r = $app->routes->route('/git')->to( namespace => 'Mojolicious::Plugin::Gitosis::Controller' );
       $r->route('/')->via('get')->to('gits#list')->name('gits_index');
       # Add git repo
       $r->route('/new')->via('post')->to('gits#create_repo')->name('gits_create');
       $r->route('/new')->via('get')->to(cb => sub { shift->render(template => 'gits/form') })->name('gits_new');
       # Add git user
       $r->route('/key')->via('post')->to('gits#add_key', dir => $conf->{git_home} )->name('gits_key');
       $r->route('/key')->via('get')->to(cb => sub { shift->render(template => 'gits/key_form') })->name('gits_key_form');
       # Add git server
       $r->route('/server/key')->via('post')->to('gits#add_server_key', dir => $conf->{git_home} )->name('gits_server_key');
       $r->route('/server/key')->via('get')->to(cb => sub { shift->render(template => 'gits/key_server_form') })->name('gits_server_key_form');
       # Show repo
       $r->route('/:repo')->via('post')->to('gits#update')->name('gits_update');
       $r->route('/:repo')->via('get')->to('gits#read')->name('gits_read');
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

