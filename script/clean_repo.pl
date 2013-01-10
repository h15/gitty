#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';

while ( <STDIN> )
{
    if ( /deleted:\s*(.*?)\n/s )
    {
        `git rm $1`;
    }
}
