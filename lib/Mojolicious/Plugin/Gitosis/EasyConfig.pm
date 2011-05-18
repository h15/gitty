package Mojolicious::Plugin::Gitosis::EasyConfig;
use strict;
use warnings;

#use POSIX qw (locale_h);
#setlocale(LC_CTYPE, 'ru_RU.UTF-8');
#setlocale(LC_ALL  , 'ru_RU.UTF-8');

our $VERSION = 0.1;

sub new {
    my ( $self, $args ) = @_;
    
    my $obj = {
        groups => {},
        repos  => {},
        file   => '',
        list => qr/([\d\w\-_@\s,.!?"';:\/\\\(\)]+)/,
        word => qr/([\d\w\-_@]+)/
    };
    
    if ( exists $args->{file} && -r $args->{file} && -w $args->{file} ) {
        $obj->{file} = $args->{file};
        
        my ( $g, $r );
        my $word = $obj->{word};
        my $list = $obj->{list};
        
        open F, $args->{file};
        for my $line (<F>) {
            chomp $line;
            
            if    ( $line =~ /^\[group $word\]$/i ) { $g = $1; $obj->{groups} = { %{$obj->{groups}}, $g => {members => [], dir => ''} } }
            elsif ( $line =~ /^\[repo $word\]$/i  ) { $r = $1; $obj->{repos}  = { %{$obj->{groups}}, $r => {desc => ''} } }
            elsif ( $line =~ /^\s*writable\s*=\s*$word\s*$/i    ) { $obj->{groups}->{$g}->{dir} = $1 }
            elsif ( $line =~ /^\s*members\s*=\s*$list\s*$/i     ) { $obj->{groups}->{$g}->{members} = [ split /\s+/, $1 ] }
            elsif ( $line =~ /^\s*description\s*=\s*$list\s*$/i ) { $obj->{repos}->{$r}->{desc} = $1 }
        }
        close F;
    }
    else {
        print STDERR "[-] Need file name!\n"             unless exists $args->{file};
        print STDERR "[-] Can't read config file!\n"     unless -r $args->{file};
        print STDERR "[-] Can't write to config file!\n" unless -w $args->{file};
    }
    
    bless $obj;
}

sub add_group {
    my ( $self, $conf ) = @_;
    
    unless ( $self->find_group( [keys %$conf]->[0] ) ) {
        $self->{groups} = { %{$self->{groups}}, %$conf }
    }
}

sub find_group {
    my ( $self, $name ) = @_;
    return $self->{groups}->{$name} if exists $self->{groups}->{$name};
}

sub group_list {
    keys( %{shift->{groups}} );
}

sub add_repo {
    my ( $self, $conf ) = @_;
    
    unless ( $self->find_repo( [keys %$conf]->[0] ) ) {
        $self->{repos} = { %{$self->{repos}}, %$conf }
    }
}

sub find_repo {
    my ( $self, $name ) = @_;
    return $self->{repos}->{$name} if exists $self->{repos}->{$name};
}

sub repo_list {
    keys( %{shift->{repo}} );
}

sub save {
    my $self = shift;
    my $str = "[gitosis]\n";
    
    for my $k ( keys %{$self->{repos}} ) {
        $str .= "\n[repo $k]\n";
        $str .= "description = " . $self->{repos}->{$k}->{desc} . "\n";
    }
    
    for my $k ( keys %{$self->{groups}} ) {
        $str .= "\n[group $k]\n";
        $str .= "writable = " . $self->{groups}->{$k}->{dir} . "\n";
        $str .= "members = " . join(' ', @{ $self->{groups}->{$k}->{members} }) . "\n";
    }
    
    open F, '>', $self->{file};
    print F $str;
    close F;
}

sub change_desc {
    my ( $self, $repo, $text ) = @_;
    
    return unless $text =~ $self->{list};
    $self->{repos}->{$repo}->{desc} = $text if exists $self->{repos}->{$repo};
}

sub change_members {
    my ( $self, $group, $text ) = @_;
    
    return unless $text =~ $self->{list};
    $self->{groups}->{$group}->{members} = [split /\s+/,$text] if exists $self->{groups}->{$group};
}

1;

__END__

=head1 NAME

Gitosis::EasyConfig - easy way to work with gitosis configure file.

=head1 METHODS

=item new({ file => $file_name})

Need file name and permissions for read and write.

=item add_group( \%conf )

    %conf = (
        group_name => {
            members => [],
            dir => repo's directory
        }
    );

=item find_group( name )

Return hash ref

    {
        members => [],
        dir => repo's directory
    }

=item group_list

Return array of groups' names.

=item add_repo( \%conf )

    %conf = (
        repo_name => {
            desc => some description
        }
    );

=item find_group( name )

Return hash as in find_group but for repo.

=item repo_list

Return array of repos' names.

=item save

Write current config into gitosis configure file.

=item change_desc( repo, text )

Change repo's description.

=item change_members( group, text )

Change group's members. Text consists users' list joined by whitespace.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

