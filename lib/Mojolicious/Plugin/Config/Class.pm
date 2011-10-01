package Mojolicious::Plugin::Config::Class;
use Mojo::Base -base;
use Storable qw(freeze);

has configs => sub { {} };

# Recursive build html tables for config structure.
sub render {
    my ( $self, $config, $parent ) = @_;

    my $ret   = '';
    $parent ||= '';
    $config ||= {};
    
    for my $k ( keys %$config ) {
        $ret .= "<tr><td>$k</td><td name='$parent-$k'>";
        
        # Branch or leaf?
        $ret .= ( ref $config->{$k} ?
            $self->render( $config->{$k}, "$parent-$k" ) :
            "<input value='" . $config->{$k} . "' name='$parent-$k-input'>"
        );
        $ret .= "</td></tr>";
    }
    return "<table>$ret</table>";
}

sub _get {
    my ( $self, $name ) = @_;
    return $self->configs->{$name};
}

sub _set {
    my ( $self, $k, $v ) = @_;
    %{$self->configs} = ( %{$self->configs}, $k, $v );
}

sub save {
    my $self = shift;
    
    {
        open  F, '>./lib/Mojolicious/Plugin/Config/config.dat' or
            die '[-] Can\'t write into ./lib/Mojolicious/Plugin/Config/config.dat';
        print F freeze( $self->configs );
        close F;
    }
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

