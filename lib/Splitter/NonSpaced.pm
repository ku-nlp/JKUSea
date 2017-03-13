package Splitter::NonSpaced;

use strict;
use warnings;
use utf8;
use base qw(Splitter);
# use Encode;
use List::Util qw[min first];

use vars qw($comma $open_kakko $close_kakko $period $dot $alphabet_or_number $itemize_header @honorifics);

$open_kakko  = qr/（|〔|［|｛|“|≪|「|『|【|\(|\[|\{/;
$close_kakko = qr/）|〕|］|｝|”|≫|」|』|】|\)|\]|\}/;

$period = qr/。|？|！|♪|…/;
$dot = qr/[．.:：]/;
$alphabet_or_number = qr/[A-ZＡ-Ｚa-zａ-ｚ0-9０-９]/;
$itemize_header = qr/${alphabet_or_number}．/;

my $not_delimiters = qr(Adj.|Adm.|Adv.|Asst.|Bart.|Brig.|Bros.|Capt.|Cmdr.|Col.|Comdr.|Con.|Cpl.|Dr.|Ens.|Gen.|Gov.|Hon.|Hosp.|Insp.|Lt.|MM.|Maj.|Messrs.|Mlle.|Mme.|Mr.|Mrs.|Ms.|Msgr.|Op.|Ord.|Pfc.|Ph.|Prof.|Pvt.|Rep.|Reps.|Res.|Rev.|Rt.|Sen.|Sens.|Sfc.|Sgt.|Sr.|St.|Supt.|Surg.|vs.|i.e.|e.g.|L.A.|U.S.|U.S.A.|etc.); # remove M. and v., too generic
my $not_delimiters_zen = $not_delimiters;
$not_delimiters_zen =~ tr/a-zA-Z\./ａ-ｚＡ-Ｚ．/;

sub split {
    my $this = shift;

    my ($str, $delimiters, $ignore_parentheses) = @_;
    my @chars;
    my @buf = ();
    my $sent = '';
    my $cdot = '・';
    while ($str =~ /$delimiters/) {
        my $pre = $`;
        my $cur = $&;
        $str = $'; ## this line stops incorrect coloring '
        $sent .= $pre . $cur;
        if ($cur =~ /^$dot$/) {
            # do not split between ascii characters, symbols, or abbreviations
            if ($pre =~ /[0-9０-９a-zA-Zａ-ｚＡ-Ｚ~〜～=＝+＋*＊_＿ー\-\/／]$/ && $pre !~ /[A-ZＡ-Ｚ]{2,}$/) {
                if ($str =~ /^\s*[0-9０-９a-zａ-ｚA-ZＡ-Ｚ~〜～=＝+＋*＊_＿ー\-\/／]/) {
                    next;
                }
            } elsif ($sent =~ /(?:(?:not_delimiters)|(?:not_delimiters_zen))$/) {
                next;
            }
        }

        # do not split inside parentheses blocks
        $pre = $sent;
        my $level = 0;
        unless ($ignore_parentheses) {
            # count parentheses level
            while ($pre =~ /($open_kakko)|(?:$close_kakko)/) { 
                $level += ($1) ? 1 : -1;
                # print "PRE $pre LEVEL $level\n";
                $level = 0 if ($level < 0);
                $pre = $'; #'
            }
        }
        if ($level == 0) {
            push (@buf, $sent);
            $sent = '';
        }
    }

    push (@buf, $sent . $str);
    # my $sentences = join("\n", @buf);
    # print "SENTENCES\n $sentences\n END\n";

    &FixParenthesis(\@buf);
    if ($this->{opt}{debug}) {
        print Dumper(\@buf) . "\n";
        print "-----\n";
    }

    my @buf2 = &concatSentences(\@buf);
    if ($this->{opt}{debug}) {
        print Dumper(\@buf2) . "\n";
        print "-----\n";
    }

    # $sentences = join("\n", @tmp);
    # print "SENTENCESCONCAT\n $sentences\n END\n";

    pop(@buf2) unless $buf2[-1];
    return @buf2;
}

sub concatSentences {
    my ($sentences) = @_;
    my @buff = ();
    my $tail = scalar(@{$sentences}) - 1;
    while ($tail > 0) {
        # if ($sentences->[$tail - 1] =~ /${dot}$alphabet_or_number{1,2}${dot}$/) {
        #     $sentences->[$tail - 1] .= $sentences->[$tail];
        # }
        if ($sentences->[$tail] =~ /^(?:と|っ|です)/o && $sentences->[$tail - 1] =~ /(?:！|？|$close_kakko)$/o) {
            $sentences->[$tail - 1] .= $sentences->[$tail];
            #elsif ($sentences->[$tail] =~ /^(?:と|や|の)($itemize_header)?/o && $sentences->[$tail - 1] =~ /$itemize_header$/o) {
        # bourlon 「に」以降を追加
        } elsif ($sentences->[$tail] =~ /^(?:と|や|の|に|が|で|を|は|および|及び|,|、|，)/ && $sentences->[$tail - 1] =~ /$dot$/) {
            $sentences->[$tail - 1] .= $sentences->[$tail];
        }
        else {
            unshift(@buff, $sentences->[$tail]);
        }
        $tail--;
    }
    unshift(@buff, $sentences->[0]);
    return @buff;
}

sub FixParenthesis {
    my ($sentences) = @_;
    for my $i (0 .. scalar(@{$sentences} - 1)) {
        # 1つ目の文以降で、閉じ括弧が文頭にある場合は、閉じ括弧をとって前の文にくっつける
        if (!$sentences->[$i]) {
            # has been spliced
            next;
        }
        if ($i > 0 && $sentences->[$i] =~ /^$close_kakko+/o) {
            $sentences->[$i - 1] .= $&;
            $sentences->[$i] = "$'";
        }

        # 1つ前の文と当該文に”が奇数個含まれている場合は、前の文に該当文をくっつける
        if ($i > 0) {
            my @prev = split('”', $sentences->[$i - 1], -1);
            my @curr = split('”', $sentences->[$i], -1);
            my $num_of_zenaku_quote_prev = scalar(@prev) - 1;
            my $num_of_zenaku_quote_curr = scalar(@curr) - 1;
            # my $num_of_zenaku_quote_prev = scalar(split('”', $sentences->[$i - 1], -1)) - 1;
            # my $num_of_zenaku_quote_curr = scalar(split('”', $sentences->[$i], -1)) - 1;

            if ($num_of_zenaku_quote_prev > 0 && $num_of_zenaku_quote_curr > 0) {
                if ($num_of_zenaku_quote_prev % 2 == 1 && $num_of_zenaku_quote_curr % 2 == 1) {
                    $sentences->[$i - 1] .= $sentences->[$i];
                    splice(@$sentences, $i, 1);
                }
            }
        }

        # 当該文が^$itemize_header$にマッチする場合、箇条書きと判断し、次の文とくっつける
        if (defined $sentences->[$i + 1]) {
            if ($sentences->[$i] =~ /^$itemize_header$/o) { # added o by ynaga
                $sentences->[$i] .= $sentences->[$i + 1];
                splice(@$sentences, $i + 1, 1);
            }
        }
    }
}


1;
