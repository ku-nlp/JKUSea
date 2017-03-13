#!/usr/bin/env perl

use strict;
use utf8;
use IO::Handle;
binmode STDIN, ":encoding(utf8)";
binmode STDOUT, ":encoding(utf8)";
binmode STDERR, ":encoding(utf8)";

STDOUT->autoflush(1);
STDERR->autoflush(1);

while (<STDIN>) {
    chomp;
    if (/^EOS$/) {
	print "\n";
	next;
    }
    if (/^@ /) {
	next;
    }
    my @foo = split(/\s/);
    if ($foo[3] =~ /^形容詞$/) {
	print "$foo[0]";
    } else {
	#$foo[0] =~ s/(?<=[0-9.．０-９])([万億千])/ $1 /g;  # for en-ja
	#print "$foo[0] "; # 2
	$foo[2] =~ s/(?<=[0-9.．０-９])([万億千])/ $1 /g;  # for zh-ja
	print "$foo[2]"; # 2
    }
}
