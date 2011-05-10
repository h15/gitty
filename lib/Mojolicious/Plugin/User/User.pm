package Mojolicious::Plugin::User::User;
use Mojo::Base -base;

has data => sub { {} };

sub update {
    my ( $self, $data ) = @_;
    $self->data->{$_} = $data->{$_} for keys %$data;
}

sub is_active {
    shift->data->{ban_reason} == 0 ? 1 : 0;
};

sub is_admin {
    # 3rd - is default admin's group
    my $self = shift;
    
    if ( grep { $_ == 3 } split ' ', $self->data->{groups} ) {
        return 1;
    }
    return 0;
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

