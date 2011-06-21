package Mojolicious::Plugin::User::User;

use warnings;
use strict;

use base 'Model::User::User';

sub update {
    my ( $self, $id ) = @_;
    $self->new( id => $id )->load;
}

sub is_active {
    my $self = shift;
    
    return 0 if 1 == $self->id;
    return 0 if 0 != $self->ban_reason;
    
    return 1;
};

sub is_admin {
    # 3rd - is default admin's group
    my $self = shift;
    
    if ( grep { $_ == 3 } split ' ', $self->groups ) {
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

