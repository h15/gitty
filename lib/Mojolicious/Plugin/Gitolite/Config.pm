package Mojolicious::Plugin::Gitolite::Config;
use Pony::Object;

    /**
     *  Configure Gitolite config file
     *  from usual perl script.
     */
    
    has groups      => {};
    has repos       => {};
    has file        => undef;
    has groupRights => {};
        
    sub init
        {
            my ( $this, $args ) = @_;
    
            if ( defined $args->{file} && -r $args->{file} && -w $args->{file} )
            {
                $this->file = $args->{file};
                my $w = qr/\@?[a-zA-Z0-9\-_\.]+/;
                
                open F, $this->file;
                
                /**
                 *  Config file parsing.
                 */
                my @curRepos;
                
                for my $line (<F>)
                {
                    given( $line )
                    {
                        /**
                         *  Gitolite groups definitions.
                         */
                        when( /^\s*\@($w)\s*=\s*((?:$w\s+)+)$/ )
                        {
                            for my $gr ( split /\s+/, $2 )
                            {
                                if ( substr($gr, 0, 1) eq '@' )
                                {
                                    $gr = substr $gr, 1;
                                    push @{ $this->groups->{$1} }, @{ $this->groups->{$gr} };
                                }
                                else
                                {
                                    push @{ $this->groups->{$1} }, $gr;
                                }
                            }
                        }
                        
                        /**
                         *  Repo define start
                         */
                        when( /^\s*repo\s+((?:$w\s+)+)\s*$/ )
                        {
                            my @repos = split /\s+/, $1;
                            undef @curRepos;
                            
                            for my $r ( @repos )
                            {
                                if ( substr($r, 0, 1) eq '@' )
                                {
                                    $r = substr $r, 1;
                                    push @curRepos, $this->groups->{$r};
                                }
                                else
                                {
                                    push @curRepos, $r;
                                }
                            }
                        }
                        
                        /**
                         *  Define user's rights for repos.
                         */
                        when( /^\s*(-|R|RW\+?C?D?)\s*=\s*((?:$w\s+)+)$/ )
                        {
                            my @rights = split //, $1;
                            my @users;
                            
                            for my $gr ( split /\s+/, $2 )
                            {
                                if ( substr($gr, 0, 1) eq '@' )
                                {
                                    $gr = substr $gr, 1;
                                    push @users, @{ $this->groups->{$gr} };
                                }
                                else
                                {
                                    push @users, $gr;
                                }
                            }
                            
                            for my $re ( @curRepos )
                            {
                                for my $user ( @users )
                                {
                                    for my $ri ( @rights )
                                    {
                                        $this->repos->{$re}->{$user}->{$ri}++;
                                    }
                                }
                            }
                        }
                    }
                }
                close F;
            }
            else {
                say STDERR "[-] Need file name!"             unless exists $args->{file};
                say STDERR "[-] Can't read config file!"     unless -r $args->{file};
                say STDERR "[-] Can't write to config file!" unless -w $args->{file};
            }
        }
    
    sub findGroup
        {
            my ( $this, $name ) = @_;
            
            exists $this->groups->{$name} ?
                   $this->groups->{$name} : undef;
        }
    
    sub findRepo
        {
            my ( $this, $name ) = @_;
            
            exists $this->repos->{$name} ?
                   $this->repos->{$name} : undef;
        }
    
    sub addGroup
        {
            my ( $this, $name, $list ) = @_;
        
            unless ( $this->findGroup($name) )
            {
                my @users;
                
                for my $l ( @$list )
                {
                    if ( substr($l, 0, 1) eq '@' )
                    {
                        $l = substr $l, 1;
                        
                        exists $this->groups->{$l} ?
                            push @users, @{ $this->groups->{$l} } : 1;
                    }
                    else
                    {
                        push @users, $l;
                    }
                }
            
                $this->groups->{$name} = \@users;
                
                return 1;
            }
            
            return undef;
        }

    sub addRepo
        {
            my ( $this, $name, $repo ) = @_;
            
            unless ( $self->findRepo($name) )
            {
                $this->repos->{$name} = $repo;
                
                return 1;
            }
            
            return undef;
        }

    sub save 
        {
            my $this = shift;
            my $config = "# Auto generated by Gitty.\n\n";
            
            /**
             *  Dump groups
             */
            for my $g ( keys %{ $this->groups } )
            {
                my $users = $this->groups->{$g};
                
                $config .= "\@$g = @$users\n";
            }
            
            $config = "\n";
            
            /**
             *  Dump repos
             */
            
            
            open F, '>', $self->{file};
            print F $str;
            close F;
        }

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

