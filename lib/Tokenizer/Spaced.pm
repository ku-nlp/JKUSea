package Tokenizer::Spaced;

use strict;
use warnings;
use utf8;
use base qw(Tokenizer);
# use Encode;
use List::Util qw[min first];

sub tokenize {
    my $this = shift;
    #print "XST = @$xst\n";
    #print "YST = @$yst\n";
    my %dict_cache = ();
    my ($xst, $yst, $snts_split_delete) = @_;

    my $NL = "\n";
    my $snt = join($NL, @$xst);
    # add 2014/01/30
    $snt =~ s/ +/ /g;
    $snt =~ s/^ +| +$//g; # prevent matching of "40 ma . " with the final space
    # end 2014/01/30
    my $yarticle_nospace = join('', @$yst);
    $yarticle_nospace =~ s/ //g;

    my $PUNCT = '^[()\[\]（）【】]+$';
    my @chars = split("", $snt);
    my $i = -1;
    my $res = '';
    # print "CHARS = @chars\n";
    while (1) {
        $i += 1;
        last if ($i >= @chars);
        if ($chars[$i] =~ / /) {
            $res .= ' ';
            next;
        }
        # if character at $i does not follow a word boundary (and is not the beginning of the sentence), do not try to match
        if ($i > 0 && $chars[$i-1] =~ /[a-zA-Z0-9]/) {
            $res .= $chars[$i];
            next;
        }
        # $i points to a new line, do not try to match 
        if ($chars[$i] =~ /$NL/) {
            push(@$snts_split_delete, 0);
            $res .= $chars[$i];
            next;
        }
        my $found = '';
        my $j = min(@chars-1, $i+100);
        # try matching @chars[$i..$j] in the dictionary (as a key) or in the y sentence 
        while ($j >= $i) {
            # if @chars[$i..$j] does not end on a word boundary, do not try to match
            if ($j < @chars-1 && $chars[$j+1] =~ /[a-zA-Z0-9]/) {
                $j -= 1;
                next;
            }
            # do no try to match strings ending with a space
            if ($chars[$j] =~ / /) {
                $j -= 1;
                next;
            }
            # do no try to match strings with more than 1 character and starting with a punctuation
            if ($j > $i && $chars[$i] =~ /^[.,;]/) {
                #print "YOSKIP";
                $j = $i;
                next;
            }
            my $phrase = join('', @chars[$i..$j]);
            #print "TRY $phrase\n";

            my $phrase_nospace = $phrase;
            $phrase_nospace =~ s/ //g;

            my $phrase_formatch = $phrase_nospace;
            $phrase_formatch =~ s/$NL//g;

            my $phrase_fordict = $phrase;
            $phrase_fordict =~ s/$NL//g;

            my $dict = $this->{dict};
            if (exists($dict->{$phrase_fordict})) {
                unless (exists($dict_cache{$phrase_formatch})) {
                    my @trans_list = @{$this->{dict}{$phrase_fordict}};
                    foreach my $xtoken_trans (@trans_list) {
                        #print  "lookup $xtoken trans: $xtoken_trans\n";
                        #$match_re = "($xtoken_trans)";
                        if ($yarticle_nospace =~ m/\Q$xtoken_trans/) {
                            #my @trans_list = @{$this->{dict}->{$phrase_fordict}};
                            push(@{$dict_cache{$phrase_formatch}}, $xtoken_trans);
                        }
                    }
                }
                if (exists($dict_cache{$phrase_formatch})) {
                    $found = $phrase_nospace;
                    #print "FOUND $phrase_fordict TR @{$dict_cache{$phrase_formatch}}\n";
                }
            }
            if ($yarticle_nospace =~ /\Q$phrase_formatch/) {
                $found = $phrase_nospace;
                #print "FOUND $phrase_formatch\n";
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
                #print "dict cache for [$phrase_formatch] = @{$dict_cache{$phrase_formatch}}\n";
            } 
            if ($found) {
                last;
            }
            $j -= 1;    
        }
        if ($found) {
            # replace spaces in matched string so that it is not split by match_sentences_lex_ku 
            #print "FOUND :[$found]\n";
            $found =~ s/ /＿＿/g; 
            push(@$snts_split_delete, 0);
            #print "FOUND underscored:[$found]\n";
            $res .= "${found} ";
            $i = $j;
        } else {
            if ($chars[$i] =~ /$NL/) {
                push(@$snts_split_delete, 0);
            }
            $res .= "${chars[$i]}";
        }
    }

    # remove leading/trailing/duplicate spaces
    $res =~ s/^ +| +$//g; # really needed?
    $res =~ s/ +/ /g;    
    push(@$snts_split_delete, 0); # for the last newline of the article
    #print "deleted new lines = @$snts_split_delete\n";

    my @res = split("\n",$res);
    return (\@res, \%dict_cache);
}

1;
