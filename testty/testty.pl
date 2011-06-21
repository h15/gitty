#!/usr/bin/env perl

use warnings;
use strict;
use feature qw/say switch/;

use Testty;

my $c = new Testty;
   $c->root('./test'            );
   $c->repo('testing_gitty_1'   );
   $c->serv('git.lorcode.org'   );
   $c->mail('helios_pro@mail.ru');
   $c->user('stud'              );
   
$c->info('Running Testty');

# Shorter
my $root = $c->root;
my $repo = $c->repo;
my $user = $c->user;

given ( $ARGV[0] ) {
    
    # Running first.
    # Should prepare environment.
    when ('prepare') {
        if ( $c->mount_all( qw[ /bin /sbin /lib /etc /usr/bin /usr/lib /dev /proc ] ) ) {
            my $root = $c->root;
            my $repo = $c->repo;
            exit 0 if system "cp -f testty.pl $root/testty.pl";
            exit 0 if system "cp -f Testty.pm $root/Testty.pm";
                      system "sudo rm -rf $root/$repo";
                      system "mkdir $root/$repo";
            exit 0 if system "chown -R $user:$user $root/$repo";
            $c->success('Prepare');
        }
        else {
            $c->fail('Prepare');
            exit 1;
        }
        
        # Copy self,
        # Chroot,
        # Running self (go) in weak mode.
        if ( system "chroot $root sudo su - $user -c 'perl testty.pl go'" ) {
            $c->fail('Jump');
            exit 1;
        }
        else {
            $c->success('Jump');
            $c->info("All done");
            exit 0;
        }
    }
    
    # Get project from git.
    # Build, deploy and test.
    # Send mail with test's results.
    when ('go') {
        $c->run( 'git clone git://' . $c->serv . "/$repo.git" );

        chdir $c->repo;
              $c->run( "./build.sh"  );
              $c->run( "./deploy.sh" );
              $c->run( "./test.sh"   );
        
        $c->success('Build, deploy and test');
        exit 0;
    }
    
    default {
        say "[-] Wrong params.";
        say "    Usage:";
        say "        prepare   Running first.";
        say "                  Will prepare environment.";
        say "";
        say "        go        Get project from git.";
        say "                  Build, deploy and test.";
        say "                  Send mail with test's results.";
        
        exit 1;
    }
    
}

exit 0;

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

