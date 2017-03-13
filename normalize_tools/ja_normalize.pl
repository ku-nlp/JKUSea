#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use FindBin qw($Bin);
use IPC::Open2;
use FileHandle;
use IO::Handle;
use POSIX 'WNOHANG';
STDOUT->autoflush(1);
STDERR->autoflush(1);

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

#my $fn=$ARGV[0];
#my $cmd = "cd $Bin && ./ja_normalize.sh";
my $cmd = "./ja_normalize.sh";

my $rh;
my $wh;
my $pid;

sub start_juman {
    $pid = IPC::Open2::open2($rh, $wh, "cd $Bin && $cmd");
    $wh->autoflush(1);
    $rh->autoflush(1);
    binmode($rh, ":encoding(utf8)");
    binmode($wh, ":encoding(utf8)");
}

sub stop_juman {
    close $wh;
    close $rh;
    local $?; # ignore the exit status of child
    my $kid;
    do {
        $kid = waitpid($pid, WNOHANG);
    } while $kid > 0;
}

sub split_part {
    my ($part, $cur_res) = @_;
    printf($wh "%s", "$part\n");
    my $one_part_result;
    while (<$rh>) {
        $one_part_result = $_;
        last;
    }
    chomp($one_part_result);
    $$cur_res .= $one_part_result;
}

#open IN, "<$fn" || die "$0: Can not open $fn\n";
#binmode IN, ":utf8";

start_juman();

my $input;
my $total = 0;
while (<STDIN>) {
    chomp;
    my $line = $_;
    my @line_parts;
    my @line_parts2;
    my $one_line_result;
    if (length($line) > 500) {
        @line_parts = split(/(?<=[。,、:;；：，.．\s()（）\[\]【】{}｛｝「」”"`'])/, $line);
    } else {
        @line_parts = ($line);
    }
    foreach my $part (@line_parts) {
        if (length($part) > 500) {
            @line_parts2 = $part =~ /(.{1,500})/g;
            foreach my $part2 (@line_parts2) {
                split_part($part2, \$one_line_result);
            }
        } else {
            split_part($part, \$one_line_result);
        }
    }
    print "$one_line_result\n";
}

stop_juman();
