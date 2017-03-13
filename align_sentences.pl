#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

binmode STDIN, ":encoding(utf8)";
binmode STDERR, ":encoding(utf8)";
binmode STDOUT, ":encoding(utf8)";

use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "perllib/lib/perl5";
use Config::General;
use Getopt::Long;
use File::Basename;
use Tokenizer::Spaced;
use Tokenizer::NonSpaced;
use Splitter::Spaced;
use Splitter::NonSpaced;
use Matcher;

use IPC::Open2;
use FileHandle;
use IO::Handle;
use POSIX 'WNOHANG';

my $DEFAULT_VALUES = {
    "pairs" => "zh_ja",
    #"pairs" => "zh_ja,en_ja,en_zh",
    "output_file" => "$Bin/result",
    "conf" => "$Bin/align.conf",
    "score_only" => 0,
    "dict" => "",
};

# settings loaded from config file
my (%globals, %pairs, %languages);

# global variables
# sentence splitter, tokenizers(tokenizers), matchers for each language
my %splitters;
my %tokenizers;
my %matchers;
my %normalizers;
my $opts;

my $rh;
my $wh;
my $pid;


sub usage {
    printf(" Extract and align sentences from text translation pairs read from standard input\n");
    printf(" perl align_sentences.pl [options] < [input file]\n");
    printf("  --pairs                 LIST     language pairs (csv) for which sentence alignment will be performed\n");
    printf("                                   (default: '%s')\n",
           $DEFAULT_VALUES->{"pairs"});
    printf("  --output                FILE     common part of alignment result file names\n");
    printf("                                   (default: '%s')\n",
           $DEFAULT_VALUES->{"output_file"});
    printf("  --conf                  FILE     configuration file\n");
    printf("                                   (default: '%s')\n",
           $DEFAULT_VALUES->{"conf"});
    printf("  --dict                  FILE     configuration file\n");
    printf("                                   (default: '%s')\n",
           $DEFAULT_VALUES->{"dict"});
    printf("  --score_only            BOOL     only calculate score. no sentence split/realignment\n");
    printf("                                   (default: '%s')\n",
           $DEFAULT_VALUES->{"score_only"});
}

sub main {
    load_config();

    my $ifh = \*STDIN;
    process_input_docs($ifh);

    stop_normalizers();
}

sub load_config {

    $opts = {%$DEFAULT_VALUES};
    GetOptions("h|help" => \$opts->{"help"},
               "p|pairs=s" => \$opts->{"pairs"},
               "o|output=s" => \$opts->{"output_file"},
               "c|conf=s" => \$opts->{"conf"},
               "d|dict=s" => \$opts->{"dict"},
               "s|score_only=s" => \$opts->{"score_only"}
        );

    if (defined($opts->{"help"})) {
        usage();
        exit(0);
    }

    print STDERR "load settings from file $opts->{'conf'}\n";

    my $conf_obj = Config::General->new(-ConfigFile => $opts->{conf}, -UTF8 => 1);
    my %conf = $conf_obj->getall();
    %pairs = %{$conf{pairs}};
    %languages = %{$conf{languages}};

    my $tmp_dir = $conf{globals}{tmp_dir_base};

    my $output_files_cmn = $opts->{output_file};
    my @opt_pairs = split(',', $opts->{pairs});
    my %is_opt_pairs;
    $is_opt_pairs{$_} = 1 for (@opt_pairs);

    foreach my $pair (@opt_pairs) {
        unless (exists $pairs{$pair}) {
            die "No settings for language pair '$pair' in $opts->{conf}\n";
        }
        $tmp_dir .= "_$pair";
    }
    $globals{tmp_dir} = $tmp_dir;
    mkdir $tmp_dir;

    # remove unused pairs from conf
    foreach my $pair (keys %pairs) {
        unless ($is_opt_pairs{$pair}) {
            delete $pairs{$pair};
        }
    }

    foreach my $pair (keys %pairs) {

        my $result_filename = ${output_files_cmn};
        $result_filename .= $opts->{score_only} ? '.txt' : "_${pair}.txt";

        #load dictionaries
        print STDERR "DICT:$opts->{dict}\n";
        if ($opts->{dict} =~ /no$/) {
            $pairs{$pair}{dict} = {};
        } else {
            if ($opts->{dict}) {
                $pairs{$pair}{dict} = load_dict($opts->{dict}, $pairs{$pair}{matching_ignored_chars});
            } else {
                $pairs{$pair}{dict} =~ s/BIN_DIR/$Bin/g;
                $pairs{$pair}{dict} = load_dict($pairs{$pair}{dict}, $pairs{$pair}{matching_ignored_chars});
            }
        }

        print STDERR "Will output results for '$pair' to $result_filename\n";

        open my $result_fh, '>', $result_filename or die "Could not open $result_filename: $!";
        binmode $result_fh, ":encoding(utf8)";

        $pairs{$pair}{result_fh} = $result_fh;

        my ($xlang, $ylang) = split(/_/, $pair);
        unless (exists $splitters{$xlang}) {
            $splitters{$xlang} = create_splitter($xlang);
            $normalizers{$xlang} = start_normalizer($xlang);
        }
        unless (exists $splitters{$ylang}) {
            $splitters{$ylang} = create_splitter($ylang);
            $normalizers{$ylang} = start_normalizer($ylang);
        }
        $tokenizers{$pair} = create_tokenizer($xlang, $pair);
        $matchers{$pair} = create_matcher($pair);
    }
}

sub start_normalizer {
    my ($lang) = @_;

    my $cmd = $languages{$lang}{normalize_cmd};
    $cmd =~ s/BIN_DIR/$Bin/g;

    my $rh;
    my $wh;
    $pid = IPC::Open2::open2($rh, $wh, $cmd);
    $wh->autoflush(1);
    $rh->autoflush(1);
    binmode($rh, ":encoding(utf8)");
    binmode($wh, ":encoding(utf8)");

    my $normalizer = {
        'rh' => $rh,
        'wh' => $wh,
        'pid' => $pid
    };
    return $normalizer;
}

sub stop_normalizers {
    local $?; # ignore the exit status of child
    foreach my $lang (keys %normalizers) {
        my $kid;
        do {
            $kid = waitpid($normalizers{$lang}->{pid}, WNOHANG);
        } while $kid > 0;
    }
}


sub create_tokenizer {
    my ($xlang, $pair) = @_;
    my $pair_conf = $pairs{$pair};

    if ($languages{$xlang}->{spaced}) {
        return Tokenizer::Spaced->new(
            $pair_conf->{dict},
            $pair_conf->{debug_tokenize});
    }
    return Tokenizer::NonSpaced->new(
        $pair_conf->{dict},
        $pair_conf->{debug_tokenize});
}

sub create_matcher {
    my ($pair) = @_;
    my $pair_conf = $pairs{$pair};
    return Matcher->new(
        $pair,
        $pair_conf->{max_sentence_concat}[0],
        $pair_conf->{max_sentence_concat}[1],
        $pair_conf->{matching_ignored_chars},
        $pair_conf->{unmatched_ignored_chars},
        $pair_conf->{sentence_end_penalty_chars},
        $pair_conf->{sentence_end_penalty},
        $pair_conf->{omission_score},
        $pair_conf->{debug_matching},
        $pair_conf->{dict}
        );
}

sub create_splitter {
    my ($lang) = @_;
    if ($languages{$lang}{spaced}) {
        return Splitter::Spaced->new();
    }
    return Splitter::NonSpaced->new();
}


sub normalize_sentences {
    my ($sentences, $lang, $doc_id) = @_;

    my $wh = $normalizers{$lang}->{wh};
    my $rh = $normalizers{$lang}->{rh};

    # write to normalize process
    foreach my $sentence (@$sentences) {
        print $wh "$sentence\n";
        #print "sentence: $sentence";
    }
    print $wh "\n";

    # read from normalize process
    my @normalized_sentences;
    while(<$rh>) {
        if (/^$/) {
            last;
        }
        chomp;
        #print "read $_\n";
        s/\s+/ /g; 
        push(@normalized_sentences, $_);
        #print "read ok\n";
    }
    #print "after read\n";

    # check whether all sentences have been normalized.
    # otherwise, use the original sentences for matching.
    if (scalar(@$sentences) != scalar(@normalized_sentences)) {
        print STDERR "WARNING $lang normalization error for doc $doc_id\n";
        @normalized_sentences = @$sentences;
    }

    # unlink ($doc_fn, $normalized_doc_fn);

    return \@normalized_sentences;
}

sub format_sentence_group {
    my ($fh, $sentences, $splits, $lang, $sids_str, $offset, $snts_split_delete) = @_;
    my @sids = split (',', $sids_str);
    # print $fh "$lang: ";
    my @merged_snts_list;
    my $merged_snts = '';
    for (my $i = 0; $i < @sids; $i++) {
        my $sid = $sids[$i];
        #print "$lang sentence index : $sid offset : $offset\n";
        if ("$sid" eq 'omitted') {
            # print "sentence id skip";
            next;
        }
        my $sentence = @{$sentences}[$sid - 1 + $offset];
        #print "$lang sentence : $sentence\n";
        $merged_snts .= "$sentence";
        if ($snts_split_delete && @$snts_split_delete > 0) {
            if ($sid - 1 + $offset >= @$snts_split_delete) {
                print "MISSING DATA\n";
            }
            #print "$lang split delete : @$snts_split_delete[$sentence_index-1+$offset]\n";
            while (@$snts_split_delete[$sid - 1 + $offset]) {
                $offset++;
                $sentence = @{$sentences}[$sid - 1 + $offset];
                $merged_snts .= "$sentence";
            }
        }
        if ($i == $#sids || @{$splits}[$sid + $offset]) {
            #print $fh "\n";
            #$merged_snts += "\n";
            $merged_snts =~ s/^\s+//g;
            push(@merged_snts_list, "$merged_snts");
            $merged_snts = '';
        }
    }
    for (my $i = 0; $i < @merged_snts_list; $i++) {
        my $index = @merged_snts_list > 1 ? $i + 1: '';
        print $fh "$lang$index: $merged_snts_list[$i]\n";
    }

    return $offset;
}

sub output_alignment {
    my ($sentences, $alignment, $splits, $scores, $xlang, $ylang, $doc_id, $snts_split_delete) = @_;

    my $pair = "${xlang}_${ylang}";
    my $result_fh = $pairs{$pair}{result_fh};
    my $j = 1;
    # print "SPLIT hard   = $xlang =@{$snts_split{$xlang}}\n";
    # print "SPLIT delete = $xlang =@$snts_split_delete\n";
    my $offset = 0;
    for (split /\n/, $alignment)  {
        # print "GROUP$j:$_\n";
        my ($xids, $yids) = split(' <=> ', $_);
        my $score_index = @$scores - $j;
        my $sentence_pair_id = $opts->{score_only} ? $doc_id : "$doc_id-$j";
        print $result_fh "# $sentence_pair_id score=@$scores[$score_index]\n";
        $offset = format_sentence_group($result_fh, $sentences->{$xlang}, $splits->{$xlang}, $xlang, $xids, $offset, $snts_split_delete);
        format_sentence_group($result_fh, $sentences->{$ylang}, $splits->{$ylang}, $ylang, $yids, 0);
        # print OUT "\n";
        $j += 1;
    }
}

sub align_sentences {
    my ($xst, $yst, $xlang, $ylang) = @_;

    my @snts_split_delete = ();
    my $pair = "${xlang}_${ylang}";
    
    my ($alignment, $scores);
    my $quick_tokenize = 1; # TODO parameterize
    if ($quick_tokenize) {
        my ($tokenized_xst, $matched_dict) = $tokenizers{$pair}->tokenize($xst, $yst, \@snts_split_delete);       
        ($alignment, $scores) = $matchers{$pair}->align($tokenized_xst, $yst, $matched_dict);
    } else {
        ($alignment, $scores) = $matchers{$pair}->align($xst, $yst, "");
    }

    return $alignment, $scores, \@snts_split_delete;
}

sub is_sentence_too_long {
    my ($sentences) = @_;
    foreach my $sentence (@$sentences) {
        if (length($sentence) > 200) {
            return 1;
        } 
    }
    return 0;
}

# hard split one doc line into sentences
sub hard_split_sentences {
    my ($line, $lang) = @_;

    my @hard_sentences;
    my $hard_delimiters = $languages{$lang}{sentence_hard_delimiters};
    #print "HARD DELIM $hard_delimiters\n";
    if ($hard_delimiters && !$opts->{score_only}) {
        @hard_sentences = $splitters{$lang}->split($line, $hard_delimiters);
        if (is_sentence_too_long(\@hard_sentences)) {
            my $ignore_parentheses = 1;
            @hard_sentences = $splitters{$lang}->split($line, $hard_delimiters, $ignore_parentheses);
        }
    } else {
        @hard_sentences = ($line);
    }
    
    return \@hard_sentences;
}

sub soft_split_sentence {
    my ($sentence, $lang) = @_;

    $sentence =~ s/^\s+|\s+$//g;

    my @soft_sentences;
    my $soft_delimiters = $languages{$lang}{sentence_soft_delimiters};
    #print "SOFT DELIM $soft_delimiters\n";
    if ($soft_delimiters && !$opts->{score_only}) {
        @soft_sentences = $splitters{$lang}->split($sentence, $soft_delimiters);
    } else {
        @soft_sentences = ($sentence);
    }
    # my $soft_sentences_str = join('\n', @soft_sentences);
    # print "SOFT SPLIT SENTENCE = $soft_sentences_str\n";

    my @splits;
    my $first = 1;
    foreach my $soft_sentence (@soft_sentences) {
        if ($first) {
            # mark first split (split before $sentence) as hard
            push(@splits, 1);
            $first = 0;
        } else {
            # mark splits inside $sentence as soft (beginning of a sentence candidate)
            push(@splits, 0);
        }
        #print "lang: $lang sentences = @{$sentences_lang{$lang}}";
    }
    return \@soft_sentences, \@splits;
}

sub split_sentences {
    my ($doc_lines, $lang) = @_;

    my @doc_sentences;
    my @doc_splits;

    foreach my $line (@$doc_lines) {
        my $hard_sentences = hard_split_sentences($line, $lang);
        foreach my $hard_sentence (@$hard_sentences) {
            $hard_sentence =~ s/^\s+|\s+$//g;
            my ($soft_sentences, $splits) = soft_split_sentence($hard_sentence, $lang);
            push(@doc_sentences, @$soft_sentences);
            push(@doc_splits, @$splits);
        }
    }
    # print "DOC SENTENCES @doc_sentences\n";
    return \@doc_sentences, \@doc_splits;
}

sub align_doc {
    my ($doc_id, $doc) = @_;
    unless ($opts->{score_only}) {
        $doc_id .= '-';
        $doc_id .= 'J' if exists $doc->{'ja'};
        $doc_id .= 'E' if exists $doc->{'en'};
        $doc_id .= 'C' if exists $doc->{'zh'};
    }

    my %sentences;
    my %splits;
    # normalized sentences of the doc in each language
    my %normalized_sentences; 


    for my $pair (keys %pairs) {
        my @langs = split(/_/, $pair);
        if ($doc->{$langs[0]} && $doc->{$langs[1]}) {
                
            foreach my $lang (@langs) {
                if (!exists $normalized_sentences{$lang}) {
                    ($sentences{$lang}, $splits{$lang}) = split_sentences($doc->{$lang}, $lang);
                    # print "SNTS @{$sentences{$lang}}\n";
                    $normalized_sentences{$lang} = normalize_sentences($sentences{$lang}, $lang, $doc_id);
                }
            }
            
            my ($alignment, $scores, $deleted_splits) = align_sentences($normalized_sentences{$langs[0]},
                                                                        $normalized_sentences{$langs[1]},
                                                                        $langs[0], $langs[1]);
            if (@$scores) {
                print "# $doc_id $pair score=@$scores[0]\n";
                # print "# SPLIT delete = @snts_split_delete\n";
                print $alignment;
                output_alignment(\%sentences, $alignment, \%splits, $scores,
                                 $langs[0], $langs[1],
                                 $doc_id, $deleted_splits);
            } else {
                print "# $doc_id $pair alignment error\n";
            }
        }
    }
}



sub process_input_docs {
    my ($ifh) = @_;

    my %doc;
    my $doc_id;

    while(<$ifh>)  {
        s/\s+$//g;
        if (/^# (\S+)/) {
            my $new_doc_id = $1;
            if ($doc_id) {
                align_doc($doc_id, \%doc);
            }
            %doc = ();
            $doc_id = $new_doc_id;
            $doc_id =~ s/\.xml//g;
        }
        elsif (/^(.*?): (.*)/) {
            my $lang = $1;
            my $doc_line = "$2";

            if ($languages{$lang}{ignore_input_newlines}) {
                my $lines = \@{$doc{$lang}};
                if ($lines->[-1] && $lines->[-1] =~ /[,、，]$/) {
                    $lines->[-1] .= $doc_line;
                    next;
                }
            }
            push(@{$doc{$lang}}, $doc_line);
        }
    }
    if ($doc_id) {
        align_doc($doc_id, \%doc);
    }
}

sub load_dict {
    my ($dict_fn, $ignored_chars) = @_;

    my $dict_href;
    print STDERR "Loading dictionary $dict_fn...\n";
    open D, "<$dict_fn" || die "$0: Couldn't open $dict_fn!\n";
    binmode D, ":utf8";
    while (<D>) {
        chomp;
        #s/ +/ /g;
        s/ //g; # 12/29 eval
        tr/[A-Z]/[a-z]/;

        my ($source, @translations) = split(/\t/);

        $source =~ s/$ignored_chars//g; 
        for (@translations) {
            s/$ignored_chars//g;
        }

        $source =~ s/ $//;
        $source =~ s/^ //;
        $source =~ s/^the //; # better to match "community-based" than "the community"
        $source =~ s/^[[:ascii:]]$//; # ignore entries with single ascii character as source

        next if length($source) == 0;

        # give higher priority to longer translations
        my @long_translations_first = sort { length($b) cmp length($a) } @translations;

        #print "$source <> @long_translations_first\n";

        push  @{$$dict_href{"$source"}}, @long_translations_first;
    }
    close D;
    print STDERR " done.\n";
    print STDERR "Number of entries: ", scalar keys %$dict_href, "\n";
    # print "DICT $dict\n";
    return $dict_href;
}


main();
