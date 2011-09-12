package Gitty;
use Mojo::Base 'Mojolicious';
use Gitty::Db;

# This method will run once at server start
sub startup
    {
        my $self = shift;
        
        my $db = Gitty::Db->instance;
           $db->init('Gitty::Db::Redis');
        
        my $id = $db->create( User => {
                     name => 'helios',
                     mail => 'gosha.bugov@gmail.com'
                 });
        die $id;
    }

1;
