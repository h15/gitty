#
#   Does not work
#

die;

package Gitty::Db::Redis;
use Mojo::Base -base;
use Redis;

has redis  => undef;
has prefix => 'Eerahk2I';

sub new
    {
        my ( $this, $options ) = @_;
        $this->SUPER::new();
        $this->redis( new Redis(%$options) );
    }

sub create
    {
        my ( $this, $set, $data ) = @_;
        my $px = $this->prefix;
        my $id = $this->redis->incr("$px.$set.id");
        
        $this->redis->hmset("$px.$set.$id", %$data);
        
        return $id;
    }

sub read
    {
        my ( $this, $set, $data ) = @_;
        my $px = $this->prefix;
        my $id = $this->_getId(@$data);
        
        return $this->redis->hgetall("$px.$set.$id");
    }

sub update
    {
        my ( $this, $set, $data ) = @_;
        my $px    = $this->prefix;
        my $where = $data->{where};
           $data  = $data->{data};
        
        my $id = $this->_getId(@$where);
        
        $this->redis->hmset("$px.$set.$id", %$data);
    }

sub delete
    {
        my ( $this, $set, $data ) = @_;
        my $px = $this->prefix;
        my $id = $this->_getId(@$data);
        
        $this->redis->del("$px.$set.$id");
    }

sub list
    {
        my ( $this, $set, $data ) = @_;
        my @ret;
        
        push @ret, $this->read($set, [id => $_]) for @$data;
    }

sub count
    {
        my ( $this, $set, $data ) = @_;
        my $px = $this->prefix;
        my $id = $this->_getId(@$data);
        
        $this->redis->hlen("$px.$set.$id");
    }

sub _getId
    {
        my ( $this, $set, $key, $val ) = @_;
        my $px = $this->prefix;

        return $this->redis->get("$px.$set.${key}2id.$val");
    }

1;

__END__

=head1 OVERVIEW

Redis driver for Gitty::Db.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

