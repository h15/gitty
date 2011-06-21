#!/usr/bin/env perl

use feature qw/say switch/;

package Testty;
use Mouse;

has root => (is => 'rw', isa => 'Str');
has repo => (is => 'rw', isa => 'Str');
has serv => (is => 'rw', isa => 'Str');
has mail => (is => 'rw', isa => 'Str');
has user => (is => 'rw', isa => 'Str');

sub run {
    my ( $self, $cmd ) = @_;
    system($cmd) ? exit $self->fail($cmd) : $self->success($cmd);
}

sub success {
    my ( $self, $msg ) = @_;
    say "[+] $msg successed.";
}

sub fail {
    my ( $self, $msg ) = @_;
    say "[-] $msg failed.";
    exit 1;
}

sub info {
    my ( $self, $msg ) = @_;
    say "[!] $msg.";
}

sub mount_all {
    my ( $self, @dirs ) = @_;
    
    for my $d ( @dirs ) {
        return 0 if system "mkdir -p " . $self->root . $d;
        return 0 if system "mount --bind $d ". $self->root . "$d";
    }
    
    return 1;
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

