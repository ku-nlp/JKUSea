package Matcher;

use strict;
use warnings;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use utf8;
use List::Util qw[min first];

my $MIN_SCORE = -100; 
my $BAD_SCORE = -10; 
my $window_size = 40;
# matching algorithm configuration
my $conf; 
my $quick_match = 1; # TODO parameterize

my $NL = "\n";
my $ALPHA = qr/^[A-Za-z]+$/;
my $NUM_OR_DATE = qr/^[0-9.]+[年月日]?$/;
my $PARENTHESES = qr/^[()\[\]]+$/;

sub new {
    my $class = shift;
    my @pair = split('_', shift);
    my $this = {
        'xlang' => $pair[0],
        'ylang' => $pair[1],
        'x_max_sentence_concat' => shift,
        'y_max_sentence_concat' => shift,
        'ignored_chars' => shift,
        'unmatched_ignored_chars' => shift,
        'sentence_end_penalty_chars' => shift,
        'sentence_end_penalty' => shift,
        'omission_score' => shift,
        'debug' => shift,
        'dict' => shift
    };
    #print "$_ $this->{$_}\n" foreach keys %$this;
    #$this->{"_SID"} = 0;
    bless($this, $class);
    return $this;
}



sub set_score {
    my $this = shift;
    my ($scores, $x, $y, $d) = @_;
    
    $scores->{"$x,$y"} = $d;
    # print "SET SCORE of $x $y = $d\n"; #debug
}

sub get_score {
    my $this = shift;
    my ($scores, $x, $y) = @_;

    # print "GET SCORE of $x $y = $scores->{\"$x,$y\"}\n";
    if (defined $scores->{"$x,$y"}) {
        return $scores->{"$x,$y"};
    } else {        
        #print "no score for $x $y";
        return $MIN_SCORE; # 0
    }
}



sub dp_score {
    my $this = shift;
    my ($xst, $yst, $dict, $map_scores, $scores, $i, $j, $im, $jm) = @_;
    if ($i < $im || $j < $jm) {        
        print "bad score\n";
        exit(1);
        return $MIN_SCORE;
    }
    # if ($i == 0 || $j == 0) {
    #     return -0.1;
    # }
    my $map = "";
    for (my $k=$im; $k>0; $k-=1) {
        my $elt = $i-$k;
        $map .= "$elt ";
    }
    $map .= "-";
    for (my $k=$jm; $k>0; $k-=1) {
        my $elt = $j-$k;
        $map .= " $elt";
    }
    my $base_score = $this->get_score($scores, $i-$im, $j-$jm);
    # my $diffi=$i-$im;
    # my $diffj=$j-$jm;
    # print "dp score $i - $j base: $diffi - $diffj score: $base_score map $map\n";

    if ($base_score > $MIN_SCORE) {
        $map_scores->{$map} = $this->match_sentences($xst, $yst, $dict, $map) ? $this->match_sentences($xst, $yst, $dict, $map) : 0;
        return $base_score + $map_scores->{$map};
    }
    return $MIN_SCORE;
}

sub align {
    my $this = shift;
    #$this->{xst} = shift;
    #$this->{yst} = shift;

    #print STDERR "ALIGN @_\n";
    
    my ($xst, $yst, $dict) = @_;

    #print "match dict $_ @{$dict->{$_}}\n" foreach keys %$dict;

    # remove ignored chars from match dictionary 
    # TODO sub
    my %filtered_dict = ();
    my $ignored_chars = $this->{ignored_chars};
    if ($quick_match) {
        for my $dict_key (keys %$dict) {
            my $old_key = $dict_key;
            $dict_key =~ s/$ignored_chars//g;
            $filtered_dict{$dict_key} = $dict->{$old_key};
            s/$ignored_chars//g for @{$filtered_dict{$dict_key}};
        }
    }
    #$this->{dict} = \%filtered_dict;

    # my (@lenx, @leny, $nx, $ny);

    #print "match dict $_ @{$filtered_dict{$_}}\n" foreach keys %filtered_dict;

    my @ralign = ();
    my @aligned_scores = $this->align_internal($xst, $yst, \%filtered_dict, \@ralign);

    my $aligned;
    # print STDERR "ralignsize = $@ralign\n";
    foreach (reverse @ralign) {
        $aligned .= "$_\n";
    }
    return ($aligned, \@aligned_scores);
}

sub align_internal {
    my $this = shift;

    my ($xst, $yst, $dict, $ralign) = @_;

    my $map_scores = {};
    my $scores = {};

    my @s; 
    my ($i, $j, $oi, $oj, $si, $sj, $smax);
    
    my $nx = scalar @$xst;
    my $ny = scalar @$yst;
    # my $xst_log = join('↵',@$xst);
    # my $yst_log = join('↵',@$yst);
    my $xst_log = join("\n", @$xst);
    my $yst_log = join("\n", @$yst);
    print "$this->{xlang}: $xst_log\n";
    print "$this->{ylang}: $yst_log\n";
    my %path_x = ();
    my %path_y = ();

    $this->set_score($scores, 0, 0, 0);

    # my $x_max_merge = $max_sentences_concat{"${xlang}-${ylang}"}[0];
    # my $y_max_merge = $max_sentences_concat{"${xlang}-${ylang}"}[1];
    my $x_max_merge = $this->{x_max_sentence_concat}; # {"${xlang}-${ylang}"}
    my $y_max_merge = $this->{y_max_sentence_concat};
    # print STDERR "CONCAT $x_max_merge $y_max_merge\n";

    # print "languages = $xlang $ylang max merge = $x_max_merge - $y_max_merge\n";

    my $xyratio = $nx/$ny;
    if ($xyratio > $window_size/3) {
        $xyratio = $window_size/3;
    }
    my $window_end;
    for($j = 0; $j <= $ny; $j++) {
        my $center = int($j * $xyratio);
        my $window_start = $center-$window_size>0?$center-$window_size:0;
        $window_end = $center+$window_size<$nx?$center+$window_size:$nx;
        #print "center: $center wsize: $window_size wstart: $window_start wend: $window_end\n";
        #print "align window start $window_start end $window_end nx $nx ny $ny\n";
        for($i = $window_start; $i <= $window_end; $i++) {
            if ($i == 0 && $j == 0) {
                next;
            }            
            my $k=0;
            my $maxki = 0;
            my $maxkj = 0;
            $k = 0;
            $smax = $MIN_SCORE; #$s[0];
            for (my $ki=0; $ki<$x_max_merge && $ki<=$i; $ki++) {
                for (my $kj=0; $kj<$y_max_merge && $kj<=$j; $kj++) {
                    if ($ki==0 && $kj==0) {
                        next;
                    }
                    $s[$k] = $this->dp_score($xst, $yst, $dict, 
                                             $map_scores, $scores, $i, $j, $ki, $kj);
                    #print "dp score of i=$i j=$j ki=$ki kj=$kj is $s[$k]\n";
                    if($s[$k]>$smax) {
                        #$update_max = 1;
                        $smax=$s[$k]; 
                        $maxki=$ki;
                        $maxkj=$kj;
                        #$j_max = $smax;
                    } 
                    $k++;
                }
            }

            $this->set_score($scores, $i, $j, $smax);
            if($smax > $MIN_SCORE) {
                $path_x{"$i,$j"} = $i-$maxki;
                $path_y{"$i,$j"} = $j-$maxkj;
                # print "path $i $j score=$smax maxi=$maxki maxj=$maxkj pathx = $path_x{\"$i,$j\"} pathy = $path_y{\"$i,$j\"}\n";
            } else {
                $path_x{"$i,$j"} = 0;
                $path_y{"$i,$j"} = 0;
                # print "path $i $j bad score=$smax maxi=$maxki maxj=$maxkj\n"
            }            
        }
    }

    if ($window_end < $nx) {
        $path_x{"$nx,$ny"} = $window_end;
        $path_y{"$nx,$ny"} = $ny;
        print "not all covered set score for $nx $ny = 0\n";
        $this->set_score($scores, $nx, $ny, 0);
    }

    my $n = 0;
    my @match_scores;
    push(@match_scores, $this->get_score($scores, $nx, $ny));

    for($i=$nx, $j=$ny; $i>0 || $j>0; $i = $oi, $j = $oj, $n++) {
        $oi = $path_x{"$i,$j"};
        $oj = $path_y{"$i,$j"};
        #print "2NX $nx NY $ny OI $oi OJ $oj III $i JJJ $j\n";
        if ($oi == $i and $oj == $j) {
            print "ERROR: loop in alignment best path";
            return @match_scores;
        }
        $si = $i - $oi;
        $sj = $j - $oj;

        my $imap = "";
        my @irmap;
        for (my $ki=$si; $ki>0; $ki-=1) {
            my $elt = $i-$ki;
            $imap .= "$elt ";
            $elt += 1;
            push(@irmap,$elt);                        
        }
        my $jmap = "";
        my @jrmap;
        for (my $kj=$sj; $kj>0; $kj-=1) {
            my $elt = $j-$kj;
            $jmap .= " $elt";
            $elt += 1;
            push(@jrmap,$elt);                        
        }
        #print "score of ${imap}-${jmap}:$map_scores->{\"${imap}-${jmap}\"}\n";
        my $map_score = -0.1;
        if (exists $map_scores->{"${imap}-${jmap}"}) {
            $map_score = $map_scores->{"${imap}-${jmap}"};
        }
        push(@match_scores, $map_score);
        my $ir_str = join(',',@irmap);
        my $jr_str = join(',',@jrmap);
        if (!$ir_str) {
            $ir_str = 'omitted';
        }
        if (!$jr_str) {
            $jr_str = 'omitted';
        }
        @$ralign[$n] = $ir_str. " <=> " .$jr_str;
    }
    
    # bourlon mod
    # return $n;
    # print "SCORES=@match_scores\n";
    return @match_scores;
    # get_score($nx,$ny); 
}

# sub match_sentences {
#     my $this = shift;
#     my ($map) = @_;
#     my $score = $this->match_sentences_internal($map);
# }

sub match_sentences {
    my $this = shift;
    my ($xst, $yst, $dict, $map) = @_;
    my $length_penalty = 1;

    # print "match sentences map:$map\n";
    #print "match sentences score:$score, x:$x, y:$y, ax:@x, ay:@y, nx:$nx, ny:$ny, xlen:$xlen, ylen:$ylen\n";

    my ($x, $y) = split '-', $map;
    #print STDERR "--- $map ---\n";
    my @x = split ' ', $x;
    my @y = split ' ', $y;
    
    my $nx = @x; 
    my $ny = @y;
    
    my $x_last_fragment = '';
    my $y_last_fragment = '';
    if ($nx>0) {
        $x_last_fragment = $$xst[$x[$nx-1]];
    }
    if ($ny>0) {
        $y_last_fragment = $$yst[$y[$ny-1]];
    }
    # last sentence fragment ends in the middle of a matching word
    if ($x_last_fragment =~ m/＿＿ *$/) { # should not append anymore
        print "sentence split in the middle of a matching word: $x_last_fragment\n";
        return $BAD_SCORE;
    } 
    if ($nx == 0 || $ny == 0) {
        return $this->{omission_score}; 
    }

    my $xsentences = $this->merge_sentences($xst, @x);
    my $ysentences = $this->merge_sentences($yst, @y);
   
    my $score = 0;
    if ($quick_match) {
        $score = $this->match_sentences_lex_ku($xsentences, $ysentences, $dict);
    } else {
        $score = $this->match_sentences_lex_ku_slow($xsentences, $ysentences);
    }
 
    my $final_score = $score * $length_penalty;

    my $sentence_end_penalty_chars = $this->{sentence_end_penalty_chars}; 
    if ($y_last_fragment =~ m/$sentence_end_penalty_chars *$/) {
        #print "penalty for y sentence does not end with a period: $y_last_fragment\n";
        $final_score -= $this->{sentence_end_penalty};
    }
    if ($x_last_fragment =~ m/$sentence_end_penalty_chars *$/) {
        #print "penalty for x sentence does not end with a period: $x_last_fragment\n";
        $final_score -= $this->{sentence_end_penalty};
    }
 
    print "x=@x y=@y score=$final_score xst=$$xsentences yst=$$ysentences\n" if $this->{debug};

    return $final_score; 
}


sub match_sentences_lex_ku {
    my $this = shift;
    my ($xsentences_ref, $ysentences_ref, $dict) = @_;


    my $ignored_chars = $this->{ignored_chars};
    $$xsentences_ref =~ s/$ignored_chars//g;
    $$ysentences_ref =~ s/$ignored_chars//g;

    @_ = split ' ', $$xsentences_ref;
    my $charpos = 0;
    my @xtoken_val; 

    foreach (@_) {
        $charpos += length($_);
        push(@xtoken_val, $_);
    }
    my $xchar_count = $charpos;
    my $xcovered_count = 0;
    
    $$ysentences_ref =~ s/ //g;
    my $ychar_count = length($$ysentences_ref);
    if ($xchar_count + $ychar_count == 0) {
        return 0;   
    }
    my @ycovered = (0) x $ychar_count;

    # give higher priority to long tokens
    my @long_xtoken_val = sort { length($b) cmp length($a) } @xtoken_val;

    my %match_pos; 

    foreach my $xtoken (@long_xtoken_val) {
        
        my $xtoken_nospace = $xtoken; # for english

        print "lookup $xtoken_nospace in $$ysentences_ref\n" if $this->{debug};
        my @ret;
        my $xmatched = 0;
        
        #if (!exists $dict->{$xtoken_nospace}) {
        #}
        my @trans_list;
        if (exists $dict->{$xtoken_nospace}) {
            @trans_list = @{$dict->{$xtoken_nospace}};
        }
        push (@trans_list, $xtoken_nospace);
        foreach my $xtoken_trans (@trans_list) {
            print  "lookup $xtoken trans: $xtoken_trans\n" if $this->{debug};
            if (!$match_pos{$xtoken_trans}) {
                while ($$ysentences_ref =~ m/\Q$xtoken_trans/g) {
                        # print "MATCH $xtoken\n";
                    print  "found trans $xtoken_trans of $xtoken at $-[0] - $+[0] matches=@ycovered\n" if $this->{debug};
                    push @{$match_pos{$xtoken_trans}}, [$-[0], $+[0]];
                }
            }
            foreach my $pos (@{$match_pos{$xtoken_trans}}) {
                for (my $i=@{$pos}[0]; $i<@{$pos}[1]; $i+=1)  {
                    $xmatched = 1 if $ycovered[$i] == 0;
                    $ycovered[$i] = 1;
                }
                if ($xmatched) {
                    print  "new match for trans of x token $xtoken\n" if $this->{debug};
                    last;
                }            
            }
            if ($xmatched) {
                print  "new match for trans of x token $xtoken\n" if $this->{debug};
                last;
            }
        }
        if ($xmatched) {
            #$xcovered_count += 1; # for english
            $xcovered_count += length($xtoken); # for chinese this should be better
            print "xcovered count = $xcovered_count\n" if $this->{debug};
        }
    }

    my $ycovered_count = 0;
    if ($this->{unmatched_ignored_chars}) {
        my @ychars = split('', $$ysentences_ref);
        for(my $j = 0; $j < scalar @ychars; $j++) {
            if ($ycovered[$j] == 0 && $ychars[$j] =~ /$this->{unmatched_ignored_chars}/) {
                $ycovered[$j] = 1;
            }
        }
    }
    map { $ycovered_count += $_ } @ycovered;
    print  "x match = $xcovered_count / $xchar_count \n" if $this->{debug};
    print  "y match = $ycovered_count / $ychar_count array=@ycovered\n" if $this->{debug};
    # $score = ($xcovered_count + $ycovered_count) / $xychar_count;
    #$score = $xcovered_count/$xchar_count + $ycovered_count/$ychar_count;
    #$score = ($xcovered_count/scalar(@xtoken_val) + $ycovered_count/$ychar_count)/2;
    my $score = ($xcovered_count + $ycovered_count) / ($xchar_count + $ychar_count); # 
    #$score = $xcovered_count + $ycovered_count;

    print  "TOTAL Score: $score\n" if $this->{debug};
    return $score;
}

sub match_sentences_lex_ku_slow {
    my $this = shift;
    my ($xsentences_ref, $ysentences_ref, $dict) = @_;
    
    my $ignored_chars = $this->{ignored_chars};
    $$xsentences_ref =~ s/$ignored_chars//g;
    $$ysentences_ref =~ s/$ignored_chars//g;
    
    $$xsentences_ref =~ s/ //g;
    my $xchar_count = length($$xsentences_ref);
    my $xcovered_count = 0;
    
    $$ysentences_ref =~ s/ //g;
    my $ychar_count = length($$ysentences_ref);
    if ($xchar_count + $ychar_count == 0) {
        return 0;
    }
    my @ycovered = (0) x $ychar_count;
    
    my %match_pos; 

    my @chars = split("", $$xsentences_ref);
    my $i = -1;
    my $res = '';
    while (1) {
        $i += 1;
        last if ($i >= @chars);
        next if $chars[$i] =~ / /;
        my $found = '';
        my $j = min(@chars-1, $i+21); # TODO parameterize
        while ($j >= $i) {
            if ($j > $i && $chars[$i] =~ /^[.,;$NL]/) {
                $j = $i;
                next;
            }
            my $phrase = join('', @chars[$i..$j]);
            if ($phrase =~ /$NL/ && $phrase !~ /^[[:ascii:]$NL]+$/) {
                $j -= 1;
                next;
            }
            my $xmatched = 0;
            my $phrase_nospace = $phrase;
            $phrase_nospace =~ s/ //g;
            
            my $phrase_formatch = $phrase_nospace;
            my $phrase_fordict = $phrase;
            if ($phrase =~ /^[[:ascii:]$NL]+$/) {
                $phrase_formatch =~ s/$NL//g;
                $phrase_fordict =~ s/$NL//g;
            } 
            print "TRY $phrase_formatch\n" if $this->{debug};

            while ($$ysentences_ref =~ m/\Q$phrase_formatch/g) {
                # print "MATCH $xtoken\n";
                print  "found asis $phrase_formatch at $-[0] - $+[0] matches=@ycovered\n" if $this->{debug};
                push @{$match_pos{$phrase_formatch}}, [$-[0], $+[0]];
            }
            foreach my $pos (@{$match_pos{$phrase_formatch}}) {
                for (my $i=@{$pos}[0]; $i<@{$pos}[1]; $i+=1)  {
                    if ($ycovered[$i] == 0) {
                        $xmatched = 1;
                    } 
                    $ycovered[$i] = 1;
                }
                if ($xmatched) {
                    print  "new match for trans of x token $phrase_formatch\n" if $this->{debug};
                    last;
                }         
            }
            
            unless ($xmatched) {
                if (exists($this->{dict}->{$phrase_fordict})) {
                    my @trans_list = @{$this->{dict}->{$phrase_fordict}};
                    foreach my $xtoken_trans (@trans_list) {
                        print  "lookup xtoken trans: $xtoken_trans\n" if $this->{debug};
                        #$match_re = "($xtoken_trans)";
                        
                        while ($$ysentences_ref =~ m/\Q$xtoken_trans/g) {
                            # print "MATCH $xtoken\n";
                            print  "found trans $xtoken_trans of $phrase_fordict at $-[0] - $+[0] matches=@ycovered\n" if $this->{debug};
                            push @{$match_pos{$xtoken_trans}}, [$-[0], $+[0]];
                        }
                        foreach my $pos (@{$match_pos{$xtoken_trans}}) {
                            for (my $i=@{$pos}[0]; $i<@{$pos}[1]; $i+=1)  {
                                if ($ycovered[$i] == 0) {
                                    $xmatched = 1;
                                }
                                $ycovered[$i] = 1;
                            }
                            if ($xmatched) {
                                print  "new match for trans of x token $phrase_fordict\n" if $this->{debug};
                                last;
                            }            
                        }
                        if ($xmatched) {
                            print  "new match for trans of x token $phrase_fordict\n" if $this->{debug};
                            last;
                        }
                    }
                }
            }

            # if ($xmatched) {
            #     print  "new match for trans of x token $xtoken\n" if $this->{debug};
            #     last;
            # }         
            if ($xmatched) {
                #$xcovered_count += 1; # for english
                $xcovered_count += length($phrase_nospace); # for chinese this should be better
                print "xcovered count = $xcovered_count\n" if $this->{debug};
                $i = $j;
                last;
            } else {               
                $j -= 1;
            }
        }
    }
     
    my $ycovered_count = 0;
    if ($this->{unmatched_ignored_chars}) {
        my @ychars = split('', $$ysentences_ref);
        for(my $j = 0; $j < scalar @ychars; $j++) {
            if ($ycovered[$j] == 0 && $ychars[$j] =~ /$this->{unmatched_ignored_chars}/) {
                $ycovered[$j] = 1;
            }
        }
    }
    map { $ycovered_count += $_ } @ycovered;
    print  "x match = $xcovered_count / $xchar_count \n" if $this->{debug};
    print  "y match = $ycovered_count / $ychar_count array=@ycovered\n" if $this->{debug};
    # $score = ($xcovered_count + $ycovered_count) / $xychar_count;
    #$score = $xcovered_count/$xchar_count + $ycovered_count/$ychar_count;
    #$score = ($xcovered_count/scalar(@xtoken_val) + $ycovered_count/$ychar_count)/2;
    my $score = ($xcovered_count + $ycovered_count) / ($xchar_count + $ychar_count); # 
    #$score = $xcovered_count + $ycovered_count;

    print  "TOTAL Score: $score\n" if $this->{debug};
    return $score;
}



sub merge_sentences {
    my $this = shift;
    my ($st_aref, @st) = @_;
    my ($sentences);
    for (my $k=0; $k<scalar @st; $k+=1) {
        $sentences .= "$$st_aref[$st[$k]]";
    }
    return \$sentences;
}

1;

