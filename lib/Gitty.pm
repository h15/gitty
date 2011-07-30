package Gitty;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
    my $app = shift;

    $app->plugin('i18n');
    $app->plugin('message');
    $app->plugin('form');
    $app->plugin('config');
    $app->plugin('gitosis');
    
    $app->helper (
        is => sub {
            my ($self, $type, $val) = @_;

            if  ( $type eq 'mail' ) {
                return 1 if $val =~ m/^[a-z0-9_\-.]+\@[a-z0-9_\-.]+$/i;
            }
            return 0;
        }
    );
    
    $app->helper (
        IS => sub {
            my ($self, $type, $val) = @_;
            $self->error( "It's not $type!" ) unless $self->is($type, $val);
        }
    );
    
    $app->helper (
        render_datetime => sub {
            my ($self, $val) = @_;
            
            my ( $s, $mi, $h, $d, $mo, $y ) = localtime;
            my ( $sec, $min, $hour, $day, $mon, $year ) = map { $_ < 10 ? "0$_" : $_ } localtime($val);
            
            # Pretty time.
            my $str = (
                $year == $y ?
                    $mon == $mo ?
                        $day == $d ?
                            $hour == $h ?
                                $min == $mi ?
                                    $sec == $s ?
                                        $self->l('now')
                                    :   $self->l('a few seconds ago')
                                :   ago( min => $mi - $min, $self )
                            :   ago( hour => $h - $hour, $self )
                        :   "$hour:$min, $day.$mon"
                    :   "$hour:$min, $day.$mon"
                :   "$hour:$min, $day.$mon." . ($year + 1900)
            );
            
            $year += 1900;
            
            return new Mojo::ByteStream ( qq[<time datetime="$year-$mon-${day}T$hour:$min:${sec}Z">$str</time>] );
            
            sub ago {
                my ( $type, $val, $self ) = @_;
                my $a = $val % 10;
                
                # Different word for 1; 2-4; 0, 5-9 (in Russian it's true).
                $a = (
                    $a != 1 ?
                        $a > 4 ?
                            5
                        :   2
                    :   1
                );
                
                return $val ." ". $self->l("${type}s$a") ." ". $self->l('ago');
            }
        }
    );
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Georgy Bazhukov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

