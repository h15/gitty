package Gitty::Config;
use Mojo::Base 'Class::Singleton';

use Storable qw/freeze thaw/;
use Carp;

has configs => sub { {} };
has file    => './lib/Gitty/Config/config.dat';

sub new
    {
        my $this = shift;
        
        local $/;
        
        open F, $this->file or carp "[-] Can't find " . $this->file;
        my $conf = <F>;
        close F;
        
        $this->configs = ( length $conf ? thaw $conf : {} );
        
        $this->SUPER::new();
    }

sub save
    {
        my $this = shift;
        
        open  F, '>', $this->file or carp "[-] Can't find " . $this->file;
        print F freeze($this->configs);
        close F;
    }

sub get
    {
        return shift->configs->{shift};
    }

sub set
    {
        my ( $this, $key, $val ) = @_;
        $this->configs = { %{ $this->configs }, $key => $val };
    }

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

