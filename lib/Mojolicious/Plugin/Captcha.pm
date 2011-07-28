package Mojolicious::Plugin::Captcha;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream;

our $VERSION = '0.1';

sub register {
	my ( $self, $app ) = @_;
	
	unless( $app->config('captcha') )
    {
        $app->config ( captcha => {
            disable => 0,
        });
    }
    
    my $conf = $app->config('captcha');
	
	# for example
	my @questions = (
	    [ 'q'  , 'a'   ],
	    [ 'qq' , 'aa'  ],
	    [ 'qqq', 'aaa' ],
	);
	
	$app->renderer->add_helper(
		captcha_html => sub {
		    return if $conf->{disable};
		    
			my $self = shift;
			my $id   = int rand(@questions);
			
			$self->session(captcha => $id);
			
			return new Mojo::ByteStream (
			    "<p>" . $questions[$id]->[0] . "</p><input name='answer'>"
			);
		}
	);
	$app->renderer->add_helper(
		captcha => sub {
		    return 1 if $conf->{disable};
		    
			my $self = shift;
			my $id = $self->session('captcha');
			
			return 0 if $questions[$id]->[1] ne $self->param('answer');
			return 1;
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

