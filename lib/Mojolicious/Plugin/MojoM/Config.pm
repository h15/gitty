            
        # Autogenerated by MojoM.
        # Be careful when edit it.
        
        package Mojolicious::Plugin::MojoM::Config;
        
        use base 'Rose::DB';
        
        __PACKAGE__->use_private_registry;
        __PACKAGE__->default_connect_options( mysql_enable_utf8 => 1 );
        
        use Storable 'thaw';
        
        my $a = thaw('1234   
gitty   database
gitty   password
gitty   username
	localhost   host
mysql   driver');
        
        __PACKAGE__->register_db ( %$a );
        
        1;

