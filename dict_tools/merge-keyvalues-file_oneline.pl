#!/usr/bin/env perl

use strict; 
use warnings; 

my %file2Hash;
my $DELIMITER="\t";
my $DELIMITER_VALUES="\t";

while(<STDIN>){

    chomp; 
    my $line = $_;
    my($key, @values) = split(/$DELIMITER/, $line); #$line =~ /(.*?) (.*)/;
    if ($key =~ /^\s*$/) {
        print STDERR "ignore line with empty key: $line\n";
        next;
    }
    push @{$file2Hash{$key}}, @values;
} 

foreach my $key (sort keys %file2Hash) {
    # remove duplicates in value list 
    my %seen = ();
    my @unique = grep { ! $seen{ $_ }++ } @{$file2Hash{$key}};
    # join values
    my $unique_joined = join($DELIMITER_VALUES, @unique);
    print "$key$DELIMITER$unique_joined\n"; 
}
