            
            # Autogenerated by MojoM.
            # Be careful when edit it.
            
            package Mojolicious::Plugin::MojoM::Model::Article;
            
            use base 'Mojolicious::Plugin::MojoM::Base';
            use Storable 'thaw';

            my $a = thaw('1234
   
table
articles
columns   
id   �   not_null
serial   type
title   �      length�   not_null
varchar   type
revision_id   
integer   type
status   
integer   type

pk_columns
id

unique_key
title
foreign_keys   
revision      
id   revision_id   key_columns
Model::Wiki::Revision   class');

            __PACKAGE__->meta->setup( @$a );

            1;

