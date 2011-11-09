package Pony::Object;

use feature ':5.10';

our $VERSION = '0.000005';

sub import
    {
        my $this   = shift;
        my $call   = caller;
        my $isa    = "${call}::ISA";
        my $single = 0;
        
        while ( @_ )
        {
            my $param = shift;
            
            if ( $param eq 'singleton' )
            {
                $single = 1;
                next;
            }
            
            eval "require $param";
            die  "$@\n" if $@;
            
            push @$isa, $param;
        }
        
        strict  ->import;
        warnings->import;
        feature ->import(':5.10');
        
        *{$call.'::has' } = sub { addAttr($call, @_) };
        *{$call.'::dump'} = sub { use Data::Dumper; Dumper(@_) };
        
        eval qq{
              
              package $call;
              use Acme::Comment type => 'C++',
                                one_line => 1,
                                own_line => 0;
              
              \$instance if $single;
            
              sub ${call}::new
              {
                # For singletons.
                return \$instance if defined \$instance;
                
                my \$this  = shift;
                
                #
                #   properties inheritance
                #
                
                for my \$base ( \@{"\${this}::ISA"} )
                {
                  if ( \$base->can('ALL') )
                  {
                  
                    my \$all = \$base->ALL;
                    
                    for my \$k ( keys \%\$all )
                    {
                    
                      unless ( exists \${"${call}::ALL"}{\$k} )
                      {
                        \%{"\${this}::ALL"} = ( \%{"\${this}::ALL"},
                                                \$k => \$all->{\$k} );
                      } 
                      
                    }
                    
                  }
                }
            
                my \%obj = \%{"${call}::ALL"};
                \$this = bless \\\%obj, \$this;
                
                \$instance = \$this if $single;
                
                sub ${call}::ALL { \\\%{"${call}::ALL"} }
                
                #
                #   'After' for user.
                #
                
                \$this->init(\@_) if $call->can('init');
                
                return \$this;
              
              }
        };
    }

sub addAttr
    {
        my ( $this, $attr, $value ) = @_;
        
        given ( ref $value )
        {
            # methods
            when ( 'CODE' )
            {
                *{$this."::$attr"} = $value;
            }
            
            # properties
            default
            {       
                eval qq {
                
                    \%{"${this}::ALL"} = ( \%{"${this}::ALL"},
                                          $attr => \$value );
                    
                    sub ${this}::$attr : lvalue
                    {
                      my \$this = shift;
                         \$this->{$attr};
                    }
                    
                }
            }
        }
    }

1;

__END__

=head1 EXAMPLE

package test;
use Pony::Object;

    // property
    has a => 'default value';

    // method
    has b => sub
        {
            my $this = shift;
            
            unless ( @_ )
            {
                say 'You are in method "b"';
            }
            else
            {
                say shift;
            }
        };

    /**
     *  traditional perl method
     */
    sub c
        {
            say 'Hello from method "c"';
        }

package test2;
use Pony::Object qw/test/;

    has a => 'Redefined value';

package main;
use Pony::Object;
    
    my $var = new test2;

    # test properties
    say $var->a;

    $var->a = 'new value';
    say $var->a;

    $var->a = [qw/new value/];
    say $var->a->[0];

    $var->a = {qw/new value/};
    say $var->a->{new};

    # test methods
    $var->b;
    $var->b('Another text in method "b"');

    $var->c;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

