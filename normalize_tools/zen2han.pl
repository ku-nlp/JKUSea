#!/usr/bin/perl

use utf8;
use IO::Handle;
STDOUT->autoflush(1);

if (@ARGV == 1) {
    open STDIN, "<$ARGV[0]" or die "$0: cannot open $ARGV[0]!\n";
}

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

while (<STDIN>) {

    #eval "tr/$zen/$han/";
    tr/Ａ-Ｚ/A-Z/;
    tr/ａ-ｚ/a-z/;
    tr/０-９/0-9/;
    tr/（）〔〕＜＞〈〉《》「」『』〖〗【】［］｛｝/()[]<><>""`'""[][][]{}/;
    tr/？！：∶；、，。．/?!::;,,../;
    tr/ˉ¨“′＂＇’＾”‘｀/-""'"''^"`'/;
    tr/＊＋＝〓～＿/*+==~_/;
    tr/　＃№＄％‰￥＆＠／＼｜/ ##$%%\\&@\/\\|/;

    # If added to tr/// "Malformed UTF-8 character (byte 0xff)"
    s/・/./g;
    s/－/-/g;

    # breaks tr/// ? so put it separately
    s/ˉ/-/g; 
    s/‐/-/g;

    s/…/.../g;

    s/⒑/10/g;
    s/⒒/11/g;
    s/⒓/12/g;
    s/⒔/13/g;
    s/⒕/14/g;
    s/⒖/15/g;
    s/⒗/16/g;
    s/⒘/17/g;
    s/⒙/18/g;
    s/⒚/19/g;
    s/⒛/20/g;
    s/⑴/1/g; # TODO try with (1) 
    s/⑵/2/g;
    s/⑶/3/g;
    s/⑷/4/g;
    s/⑸/5/g;
    s/⑹/6/g;
    s/⑺/7/g;
    s/⑻/8/g;
    s/⑼/9/g;
    s/⑽/10/g;
    s/⑾/11/g;
    s/⑿/12/g;
    s/⒀/13/g;
    s/⒁/14/g;
    s/⒂/15/g;
    s/⒃/16/g;
    s/⒄/17/g;
    s/⒅/18/g;
    s/⒆/19/g;
    s/⒇/20/g;
    s/①/1/g; # TODO try with (1) 
    s/②/2/g;
    s/③/3/g;
    s/④/4/g;
    s/⑤/5/g;
    s/⑥/6/g;
    s/⑦/7/g;
    s/⑧/8/g;
    s/⑨/9/g;
    s/⑩/10/g;
    s/㈠/1/g; # TODO try with (1) 
    s/㈡/2/g;
    s/㈢/3/g;
    s/㈣/4/g;
    s/㈤/5/g;
    s/㈥/6/g;
    s/㈦/7/g;
    s/㈧/8/g;
    s/㈨/9/g;
    s/㈩/10/g;
    s/Ⅰ/I/g;
    s/Ⅱ/II/g;
    s/Ⅲ/III/g;
    s/Ⅳ/\IV/g;
    s/Ⅴ/V/g;
    s/Ⅵ/VI/g;
    s/Ⅶ/VII/g;
    s/Ⅷ/VIII/g;
    s/Ⅸ/IX/g;
    s/Ⅹ/X/g;
    s/Ⅺ/XI/g;
    s/Ⅻ/XII/g;

    print $_;
}
    

1;

