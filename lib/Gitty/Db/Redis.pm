package Gitty::Db::Redis;
use Redis;
use Carp;
use feature qw/switch/;

has redis => undef;

sub new
    {
        my ( $this, $options ) = @_;
        $this->redis = new Redis(%$options);
        $this->SUPER::new();
    }

sub create
    {
        my ( $this, $type, $data ) = @_;
        
        given($type)
        {
            when('hash')
            {
                
            }
            
            when('array')
            {
                
            }
            
            when('string')
            {
            
            }
        }
    }

sub read
    {
        my ( $this, $type, $data ) = @_;
        
        $this->driver->can('read') ?
            $this->driver->read($data) :
            carp "Can't find method 'read' in " . $this->driver;
    }

sub update
    {
        my ( $this, $type, $data ) = @_;
        
        $this->driver->can('update') ?
            $this->driver->update($data) :
            carp "Can't find method 'update' in " . $this->driver;
    }

sub delete
    {
        my ( $this, $type, $data ) = @_;
        
        $this->driver->can('delete') ?
            $this->driver->delete($data) :
            carp "Can't find method 'delete' in " . $this->driver;
    }

sub list
    {
        my ( $this, $type, $data ) = @_;
        
        $this->driver->can('list') ?
            $this->driver->list($data) :
            carp "Can't find method 'list' in " . $this->driver;
    }

sub count
    {
        my ( $this, $type, $data ) = @_;
        
        $this->driver->can('count') ?
            $this->driver->count($data) :
            carp "Can't find method 'count' in " . $this->driver;
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

