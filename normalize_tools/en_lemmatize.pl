#!/usr/bin/env perl

use strict;
use utf8;
use warnings;
use Lemmatize;

STDOUT->autoflush(1);
STDERR->autoflush(1);

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

my $lemma = new Lemmatize();

while (<STDIN>) {
    chomp;
    my $buf = "";
    foreach my $word (split(/ /)) {
        my $lem = $word;
        my (@lems) = $lemma->lemmatize($lem);
        $lem = $lems[0] if (@lems > 0);
        $buf .= $lem.' ';
    }
    $buf =~ s/ $//;
    print $buf, "\n";
}
