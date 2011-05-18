package Mojolicious::Plugin::Sql;
use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = 0.1;

sub register {
    my ( $self, $app, $conf ) = @_;
    
    $app->fatal('Config must be defined.') unless defined %$conf;
    
    my $data = Mojolicious::Plugin::Sql::Abstract->new($conf);
    
    $app->fatal("Cann't init data base.") unless $data;
    
    $app->helper(
        # For querys like $self->data->read,
        # where read is a method of Data.
        data => sub { $data }
    );
}

package Mojolicious::Plugin::Sql::Abstract;

use DBIx::Simple;
use SQL::Abstract;

sub new {
    my ( $self, $conf ) = @_;
    
    if( $conf->{user} eq 'gitty' && $conf->{passwd} eq 'password' ) {
        die "[-] Please change default data base params.\n",
            "    You can get more information in README file.\n"
    }
    
    # init database handler.
    my $h = DBIx::Simple->connect (
        @$conf{ qw/host user passwd/ },
        {
            # some options.
            RaiseError => 1,
            mysql_enable_utf8 => 1
        }
    ) or return 0;
    
    $h->abstract = SQL::Abstract->new (
        case    => 'lower',
        logic   => 'and',
        convert => 'upper'
    );
    
    my $obj = {
        db      => $h,
        prefix  => $conf->{prefix}
    };
    
    bless $obj, $self;
}

sub read_one { shift->read(@_) }

sub read {
    my $self = shift;
    my $table = shift;
    
    # if input like (table, {where})
    ( $_[1], $_[0] ) = ( $_[0], '*' ) unless $_[1];
    
    [$self->{db}->select( $self->{prefix} . $table, @_ )->hashes]->[0];
}

sub list {
    my $self = shift;
    my $table = shift;
    
    # if input like (table, {where})
    ( $_[1], $_[0] ) = ( $_[0], '*' ) unless $_[1];
    
    $self->{db}->select( $self->{prefix} . $table, @_ )->hashes;
}

# Params: table, {fields}, {where}
sub update {
    my $self = shift;
    my $table = shift;
            
    $self->{db}->update( $self->{prefix} . $table, @_ );
}

# Params: table, {fields}
sub create {
    my $self = shift;
    my $table = shift;
            
    $self->{db}->insert( $self->{prefix} . $table, @_ );
    
    return $self->{db}->last_insert_id(undef, undef, $self->{prefix} . $table, undef);
}

# Params: table, {where}
sub delete {
    my $self = shift;
    my $table = shift;
            
    $self->{db}->delete( $self->{prefix} . $table, @_ );
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

