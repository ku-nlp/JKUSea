package Tokenizer::NonSpaced;

use strict;
use warnings;
use utf8;
use base qw(Tokenizer);
#use Encode;
use List::Util qw[min first];

my $NL = "\n";
my $ALPHA = qr/^[A-Za-z]+$/;
my $NUM_OR_DATE = qr/^[0-9.]+[年月日]?$/;
my $PARENTHESES = qr/^[()\[\]]+$/;

sub tokenize {
    my $this = shift;
    my ($xst, $yst, $unused) = @_;

    my %dict_cache = ();

    # print "XST = @$xst\n";
    # print "YST = @$yst\n";

    my $snt = join($NL, @$xst);
    my $yarticle = join('', @$yst);
    # TODO parameterize
    # $snt =~ s/[.,;:]//g; # 12/29 eval
    # $yarticle =~ s/[.,;:]//g;

    my $yarticle_nospace = $yarticle;
    $yarticle_nospace =~ s/ //g;

    #$yarticle_nospace =~ s/[.,;:]//g; # 12/29 eval

    my @chars = split("", $snt);
    my $i = -1;
    my $res = '';
    while (1) {
        $i += 1;
        last if ($i >= @chars);
        next if $chars[$i] =~ / /;
        my $found = '';
        my $j = min(@chars-1, $i+100); # TODO parameterize
        while ($j >= $i) {
            if ($j > $i && $chars[$i] =~ /^[.,:;$NL]/) {
                last;
            }
            my $phrase = join('', @chars[$i..$j]);
            if ($phrase =~ /$NL/ && $phrase !~ /^[[:ascii:]$NL]+$/) {
                $j -= 1;
                next;
            }
            my $phrase_nospace = $phrase;
            $phrase_nospace =~ s/ //g;

            my $phrase_formatch = $phrase_nospace;
            #my $phrase_fordict = $phrase; # 12/29 eval
            my $phrase_fordict = $phrase_nospace;
            if ($phrase =~ /^[[:ascii:]$NL]+$/) {
                $phrase_formatch =~ s/$NL//g;
                $phrase_fordict =~ s/$NL//g;
            } else {
            }
            print "TRY $phrase_formatch\n" if $this->{debug};

            if (exists($this->{dict}->{$phrase_fordict})) {
                unless (exists($dict_cache{$phrase_formatch})) {
                    my @trans_list = @{$this->{dict}->{$phrase_fordict}};
                    foreach my $xtoken_trans (@trans_list) {
                        print  "lookup xtoken trans: $xtoken_trans\n" if $this->{debug};
                        #$match_re = "($xtoken_trans)";
                        if ($yarticle_nospace =~ m/\Q$xtoken_trans/) { #1229 eval
                        #if ($yarticle =~ m/\Q$xtoken_trans/) {
                            #my @trans_list = @{$this->{dict}->{$phrase_fordict}};
                            push(@{$dict_cache{$phrase_formatch}}, $xtoken_trans);
                            print "FOUND $phrase TR @{$this->{dict}->{$phrase_fordict}}\n" if $this->{debug};
                        }
                    }
                }
                if (exists($dict_cache{$phrase_formatch})) {
                    $found = $phrase_nospace;
                }
            }
            if ($yarticle_nospace =~ /\Q$phrase_formatch/) {
                $found = $phrase_nospace;
                print "FOUND asis $phrase_formatch\n" if $this->{debug};
                if (exists ($dict_cache{$phrase_formatch})) {
                    my @unsorted_trans_list;
                    @unsorted_trans_list = @{$dict_cache{$phrase_formatch}};
                    unless (first { $_ eq $phrase_formatch } @unsorted_trans_list) {
                        push(@unsorted_trans_list, $phrase_formatch);
                        my @sorted_trans_list = sort { length($b) cmp length($a) } @unsorted_trans_list;
                        $dict_cache{$phrase_formatch} = \@sorted_trans_list;
                    } else {
                        #print "$phrase_formatch is already in @{$dict_cache{$phrase_formatch}}\n";
                    }
                } else {
                    my @trans_list = ($phrase_formatch);
                    $dict_cache{$phrase_formatch} = \@trans_list;
                }
                print "dict cache for [$phrase_formatch] = @{$dict_cache{$phrase_formatch}}\n" if $this->{debug};
            }
            if ($found) {
                last;
            }
            # if ($phrase_formatch =~ $PARENTHESES
            #     || $phrase_formatch =~ $NUM_OR_DATE
            #     || $phrase_formatch =~ $ALPHA) {
            #     print "FOUND alphanum $phrase\n" if $this->{debug};
            #     $found = $phrase_nospace;
            #     my @trans_list = ($phrase_formatch);
            #     $dict_cache{$phrase_formatch} = \@trans_list;
            #     last;
            # }
            $j -= 1;
        }
        if ($found) {
            $res .= "$found ";
            $i = $j;
        } else {
            $res .= "$chars[$i] ";
        }
    }
    $res =~ s/ +/ /g;

    my @res = split("\n",$res);
    return (\@res, \%dict_cache);
}

1;
