package Gitty::Db::Driver::Dbi;
use Mojo::Base -base;

use DBIx::Simple;
use SQL::Abstract;
use SQL::Abstract::Limit;

has dbh => undef;
has px  => undef;

#
#   Init database handler.
#
sub new
    {
        my $this = shift;
           $this->SUPER::new();
        
        my $conf = shift;
        my $host = $conf->{host};
        
        #
        #   Init connection.
        #
        my $dbh = DBIx::Simple->connect (
            @$conf{ qw/host user passwd/ },
            {
                RaiseError => 1,
                mysql_enable_utf8 => 1
            }
        ) or die "[-] Can't connect to database ";
        
        #
        #   Add abstract queries support.
        #
        $dbh->abstract = SQL::Abstract->new (
            case    => 'lower',
            logic   => 'and',
            convert => 'upper'
        );
        
        #
        #   Add select limit support.
        #
        $dbh = SQL::Abstract::Limit->new( limit_dialect => $dbh );
        
        $this->dbh($dbh);
        $this->px($conf->{'prefix'});
        
        return $this;
    }

#
#   Create database record and return id.
#
sub create
    {
        my ( $this, $table, $data, $id ) = @_;
        my $opt = {};
        $id ||= 'id';
        
        $opt = {returning => $id} if defined wantarray;
                
        return $this->dbh->insert( $this->px . $table, $data, $opt );
    }

#
#   Get one record from table.
#
sub read
    {
        my ( $this, $table, $where ) = @_;
        
        return [ $this->dbh->select (
                    $this->px . $table, '*',
                    $where, {}, 1, 0 )->hashes ]->[0];
    }

#
#   Get many records from table.
#
sub list
    {
        my ( $this, $table, $where, $order, $limit, $offest ) = shift;
        
        $order ||= { -desc => 'id' };
        $limit ||= 20;
        $offset||= 0;
        $where ||= {};
        
        return $this->dbh->select (
                    $this->px . $table, '*',
                    $where, $order, $limit, $offset )->hashes;
    }

#
#   Update records
#   
sub update
    {
        my ( $this, $table, $data, $where ) = shift;
        
        $this->dbh->update( $this->px . $table, $data, $where );
    }

#
#   Delete records
#
sub delete
    {
        my ( $this, $table, $where ) = shift;
                
        $this->{'db'}->delete( $this->px . $table, $where );
    }

#
#   Show much fields we can get by list
#   with the same where condition.
#
sub count
    {
        my ( $this, $table, $where ) = shift;

        $where ||= {};
        
        return $this->dbh->select (
                    $this->px . $table, 'COUNT(*)', $where )->hashes;
    }

#
#   Get database handler.
#
sub raw
    {
        return shift->dbh;
    }

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
