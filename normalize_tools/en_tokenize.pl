#!/usr/bin/env perl

use strict;
use utf8;
use warnings;

STDOUT->autoflush(1);
STDERR->autoflush(1);

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

while (<STDIN>) {
    chomp;
    # put space around colons and comas, unless they're surrounded by numbers
    s/(\d)\.(\d)/$1DOTTKN$2/g;
    #$seg =~ s/\./DOTTKN/g;
    s/(\d)\:(\d)/$1COLONTKN$2/g;
    s/(\d)\,(\d)/$1COMATKN$2/g;
    s/-/HYPHENTKN/g;

    s/\W/ $& /g; # bourlon del for "-"
    s/(\d)DOTTKN(\d)/$1\.$2/g;
    s/(\d)COLONTKN(\d)/$1\:$2/g;
    s/(\d)COMATKN(\d)/$1$2/g;
    s/HYPHENTKN/-/g;
    
    print "$_\n";
}
