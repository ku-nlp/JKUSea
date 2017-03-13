package Splitter::Spaced;

use strict;
use warnings;
use utf8;
use base qw(Splitter);
# use Encode;
use List::Util qw[min first];

# use vars qw($comma $open_kakko $close_kakko $period $dot $alphabet_or_number $itemize_header @honorifics);

# @honorifics = qw(Adj. Adm. Adv. Asst. Bart. Brig. Bros. Capt. Cmdr. Col. Comdr. Con. Cpl. Dr. Ens. Gen. Gov. Hon. Hosp. Insp. Lt. M. MM. Maj. Messrs. Mlle. Mme. Mr. Mrs. Ms. Msgr. Op. Ord. Pfc. Ph. Prof. Pvt. Rep. Reps. Res. Rev. Rt. Sen. Sens. Sfc. Sgt. Sr. St. Supt. Surg. vs. v.);
# antoine add i.e. ~ viz. do not include lowercase "nov." (November) because it is very rare and "sp. nov." quite frequent[
my $honorifics = qr/(Adj|Adm|Adv|Asst|Bart|Brig|Bros|Capt|Cmdr|Col|Comdr|Con|Cpl|Dr|Ens|Gen|Gov|Hon|Hosp|Insp|Lt|M|MM|Maj|Messrs|Mlle|Mme|Mr|Mrs|Ms|Msgr|Op|Ord|Pfc|Ph|Prof|Pvt|Rep|Reps|Res|Rev|Rt|Sen|Sens|Sfc|Sgt|Sr|St|Supt|Surg|v\.s|vs|i\.e|e\.g|[Ff]ig|[Rr]ef|[Ee]x|[Aa]pprox|p|[Vv]ol|[Jj]an|[Ff]eb|[Mm]ar|[Aa]pr|[Jj]un|[Jj]ul|[Aa]ug|[Ss]ep|[Ss]ept|[Oo]ct|Nov|[Dd]ec|No|[Nn]os|cf|ca|ex|ibid|[Pp]|viz)\./; 
my $num_prefix = qr/no\./; 

my $open_parenthesis  = qr/[({[]/;
my $close_parenthesis = qr/[)}\]]/;
my $open_double_quotes = qr/[“]/;
my $close_double_quotes = qr/[“"]/;
my $open_char = qr/$open_parenthesis/;
my $close_char = qr/$close_parenthesis/;
my $open_quote  = qr/[“`]/;
my $close_quote = qr/["']/;
my $quote  = qr/($open_quote|$close_quote)/;

sub split {
    my $this = shift;

    my ($paragraph, $delimiters, $ignore_parentheses) = @_;

    # antoine add
    AddSpaceAfterPunct(\$paragraph);
    RemoveSpaceBeforePunct(\$paragraph);
    RemoveSpacesFromAbbreviations(\$paragraph);
    AddSpaceToParentheses(\$paragraph);

    my @sentences;
    my @words;
    my $sentence = '';

    # Split the paragraph into words
    @words = split(" ", $paragraph);

    my $open_parenthesis_count = 0;
    my $open_double_quotes = 0;
    my $open_quotes = 0;


    for my $i (0..$#words)
    {
        my $newword = $words[$i];
                
        # Print the words
        #print "word is: ($newword)\n";

        unless ($ignore_parentheses) {
            my $open = () = $newword =~ /$open_char/g;
            $open_parenthesis_count += $open;
            if ($open_parenthesis_count > 0) {
                my $close = () = $newword =~ /$close_char/g;
                $open_parenthesis_count -= min($close, $open_parenthesis_count);
            }
        }
        # print "dq = $open_parenthesis_count\n";
        #my $word_double_quotes = () = $newword =~ /[“"]/g;
        #$open_double_quotes = ($open_double_quotes + $word_double_quotes) % 2;
        # print "after dq = $open_parenthesis_count word = $word_double_quotes\n";
        # my $word_quotes = () = $newword =~ /('[^0-9]|'$)/;
        # $open_quotes = ($open_quotes + $word_quotes) % 2;
                
        my $pos = -1;
        my $candidate = '';

        ## print "$newword word = $newword | double = $word_double_quotes $open_double_quotes | parent = $open_parenthesis_count\n";
        if ($open_double_quotes || $open_parenthesis_count) {
            # print "NO word = $newword double parent = $open_parenthesis_count\n";
        } else {
            # Check the existence of a candidate
            my $period_pos = -1;
            my $question_pos = -1;
            my $exclam_pos = -1;
            my $col_pos = -1;  # antoine add

            # antoine. only use delimiters specified by the user
            if ('.' =~ /$delimiters/) {
                $period_pos = rindex($newword, ".");
            }
            if ('?' =~ /$delimiters/) {
                $question_pos = rindex($newword, "?");
            }
            if ('!' =~ /$delimiters/) {
                $exclam_pos = rindex($newword, "!");
            }
            # antoine. add split on ;
            if (';' =~ /$delimiters/) {
                $col_pos = rindex($newword, ";");
            }

            # Determine the position of the rightmost candidate in the word
            $pos = $period_pos;
            $candidate = ".";
            if ($question_pos > $period_pos)
            {
                $pos = $question_pos;
                $candidate = "?";
            }
            if ($exclam_pos > $pos)
            {
                $pos = $exclam_pos;
                $candidate = "!";
            }
            if ($col_pos > $pos)
            {
                $pos = $col_pos;
                $candidate = ";";
            }
        }

        # Do the following only if the word has a candidate
        if ($pos != -1)
        {
            my $wm1 = "NP";
            my $wm1P = "NP";
            my $wm2 = "NP";
            my $wm2C = "NP";
            
            my $wp1 = "NP";
            my $wp1C = "NP";
            my $wp1N = "NP"; # antoine add check for "number after split"
            my $wp2 = "NP";
            my $wp2C = "NP";

            # Check the previous word
            if (!defined($words[$i - 1]))
            {
                $wm1 = "NP";
                $wm1P = "NP";
                $wm2 = "NP";
                $wm2C = "NP";
            }
            else
            {
                $wm1 = $words[$i - 1];
                #$wm1C = Capital($wm1);
                $wm1P = ($wm1 =~ /[.;]$/);
                
                # Check the word before the previous one
                if (!defined($words[$i - 2]))
                {
                    $wm2 = "NP";
                    $wm2C = "NP";
                }
                else
                {
                    $wm2 = $words[$i - 2];
                    $wm2C = Capital($wm2);
                }
            }
            # Check the next word
            if (!defined($words[$i + 1]))
            {
                $wp1 = "NP";
                $wp1C = "NP";
                $wp2 = "NP";
                $wp2C = "NP";
            }
            else
            {
                $wp1 = $words[$i + 1];
                $wp1C = Capital($wp1);
                $wp1N = NotLowerCase($wp1); # antoine add

                # Check the word after the next one
                if (!defined($words[$i + 2]))
                {
                    $wp2 = "NP";
                    $wp2C = "NP";
                }
                else
                {
                    $wp2 = $words[$i + 2];
                    $wp2C = Capital($wp2);
                }
            }

            my $prefix = "sp";
            # Define the prefix
            if ($pos == 0)
            {
                $prefix = "sp";
            }
            else
            {
                $prefix = substr($newword, 0, $pos);
            }
            my $prC = Capital($prefix);

            # Define the suffix
            my $suffix = "sp";
            if ($pos == length($newword) - 1)
            {
                $suffix = "sp";
            }
            else
            {
                $suffix = substr($newword, $pos + 1, length($newword) - $pos);
            }
            my $suC = Capital($suffix);

            # Call the Sentence Boundary subroutine
            my $prediction = Boundary($candidate, $wm2, $wm1, $prefix, $suffix, $wp1,
                                      $wp2, $wm2C, $wm1P, $prC, $suC, $wp1C, $wp2C, $wp1N);
            
            # Append the word to the sentence
            $sentence = join ' ', $sentence, $words[$i];
            #print "SENTENCE $sentence\n";
            if ($prediction eq "Y")
            {
                # Eliminate any leading whitespace
                # $sentence = substr($sentence, 1); # antoine add. do this in aligner final output
                
                push(@sentences, $sentence);
                $sentence = "";
            }
        }
        else
        {
            # If the word doesn't have a candidate, then append the word to the sentence
            $sentence = join ' ', $sentence, $words[$i];
        }
    }
    if ($sentence ne "")
    {
        # Eliminate any leading whitespace
        #$sentence = substr($sentence, 1);

        push(@sentences, $sentence);
        $sentence = "";
    }
    return @sentences;
}

sub get_sentences
{
    my ($this) = @_;

    return @{$this->{sentences}};
}

# This subroutine returns "Y" if the argument starts with a capital letter.
sub Capital
{
   my ($substring);

   $substring = substr($_[0], 0, 1);
   if ($substring =~ /[A-Z]/)
   {
      return "Y";
   }
   else
   {
      return "N";
   }
}

# antoine add
# This subroutine returns "Y" if the argument starts with something other than lowercase alphabet.
sub NotLowerCase
{
   my ($substring);

   $substring = substr($_[0], 0, 1);
   if ($substring =~ /[^a-z]/)
   {
      return "Y";
   }
   else
   {
      return "N";
   }
}

# This subroutine does all the boundary determination stuff
# It returns "Y" if it determines the candidate to be a sentence boundary,
# "N" otherwise
sub Boundary
{
   # Declare local variables
   my($candidate, $wm2, $wm1, $prefix, $suffix, $wp1, $wp2, $wm2C, $wm1P,
         $prC, $suC, $wp1C, $wp2C, $wp1N) = @_;

   # Check if the candidate was a question mark or an exclamation mark
   if ($candidate eq "?" || $candidate eq "!")
   {
      # Check for the end of the file
      if ($wp1 eq "NP" && $wp2 eq "NP")
      {
         return "Y";
      }
      # Check for the case of a question mark followed by a capitalized word
      if ($suffix eq "sp" && $wp1C eq "Y")
      {
         return "Y";
      }
      if ($suffix eq "sp" && StartsWithQuote($wp1))
      {
         return "Y";
      }
      if ($suffix eq "sp" && $wp1 eq "--" && $wp2C eq "Y")
      {
         return "Y";
      }
      if ($suffix eq "sp" && $wp1 eq "-RBR-" && $wp2C eq "Y")
      {
         return "Y";
      }
      # This rule takes into account vertical ellipses, as shown in the
      # training corpus. We are assuming that horizontal ellipses are
      # represented by a continuous series of periods. If this is not a
      # vertical ellipsis, then it's a mistake in how the sentences were
      # separated.
      if ($suffix eq "sp" && $wp1 eq ".")
      {
         return "Y";
      }
      if (IsRightEnd($suffix) && IsLeftStart($wp1))
      {
         return "Y";
      }
      else
      {
         return "N";
      }
   }
   elsif ($candidate eq ";")
   {
       if ($suffix eq "sp") {
           return "Y";
       }
       return "N";
   }
   else
   {
       # bourlon add. do not split on "1. This", split on "Fig. 1. This 
      if (($wm1 eq "NP" || $wm1P) && $prefix =~ /^[0-9]+$/ && !(IsHonorific($wm1) || IsNumPrefix($wm1)))
      {
         return "N";
      }
      # Check for the end of the file
      if ($wp1 eq "NP" && $wp2 eq "NP")
      {
         return "Y";
      }
      if ($suffix eq "sp" && StartsWithQuote($wp1))
      {
         return "Y";
      }
      if ($suffix eq "sp" && StartsWithLeftParen($wp1))
      {
         return "Y";
      }
      if ($suffix eq "sp" && $wp1 eq "-RBR-" && $wp2 eq "--")
      {
         return "N";
      }
      if ($suffix eq "sp" && IsRightParen($wp1))
      {
         return "Y";
      }
      # This rule takes into account vertical ellipses, as shown in the
      # training corpus. We are assuming that horizontal ellipses are
      # represented by a continuous series of periods. If this is not a
      # vertical ellipsis, then it's a mistake in how the sentences were
      # separated.
      if ($prefix eq "sp" && $suffix eq "sp" && $wp1 eq ".")
      {
         return "N";
      }
      if ($suffix eq "sp" && $wp1 eq ".")
      {
         return "Y";
      }
      if ($suffix eq "sp" && $wp1 eq "--" && $wp2C eq "Y"
            && EndsInQuote($prefix))
      {
         return "N";
      }
      if ($suffix eq "sp" && $wp1 eq "--" && ($wp2C eq "Y" ||
               StartsWithQuote($wp2)))
      {
         return "Y";
      }
      if ($suffix eq "sp" && $wp1C eq "Y" &&
           ($prefix eq "p.m" || $prefix eq "a.m") && IsTimeZone($wp1))
      {
         return "N";
      }
      # antoine add check for number
      # Check for the case when a character other than lowercase alphabet follows a period,
      # and the prefix is a honorific
      # if ($suffix eq "sp" && $wp1C eq "Y" && IsHonorific($prefix.".")) 
      if ($suffix eq "sp" && $wp1N eq "Y" && IsHonorific($prefix."."))
      {
         return "N";
      }
      if ($suffix eq "sp" && $wp1 =~ /^[0-9]/ && IsNumPrefix($prefix."."))
      {
         return "N";
      }
      # antoine del. cannot see the point of this rule
      # Prevent splitting on simple things like [to “acceptance". Many patients who hav].
      #
      # Check for the case when a capitalized word or number follows a period,
      # and the prefix is a honorific
      # if ($suffix eq "sp" && $wp1C eq "Y" && StartsWithQuote($prefix))
      # {
      #    return "N";
      # }

      # antoine todo. could be removed. The rule "capitalized word following a period" below is enough
      # This rule checks for prefixes that are terminal abbreviations
      if ($suffix eq "sp" && $wp1C eq "Y" && IsTerminal($prefix))
      {
         return "Y";
      }
      # Check for the case when a capitalized word follows a period and the
      # prefix is a single capital letter
      if ($suffix eq "sp" && $wp1C eq "Y" && $prefix =~ /^([A-Z]\.)*[A-Z]$/)
      {
         return "N";
      }
      # Check for the case when a capitalized word follows a period
      if ($suffix eq "sp" && $wp1C eq "Y")
      {
         return "Y";
      }
      # antoine add
      # Check for the case when a number follows a period
      if ($suffix eq "sp" && $wp1N eq "Y")
      {
         return "Y";
      }
      # antoine add second line in condition (do not split on small parentheses blocks)
      if (IsRightEnd($suffix) && IsLeftStart($wp1) && 
          !(StartsWithLeftParen($prefix) || StartsWithLeftParen($wm1) || StartsWithLeftParen($wm2)))  
      {
         return "Y";
      }
   }
   return "N";
}


# This subroutine checks to see if the input string is equal to an element
# of the @honorifics array.
sub IsHonorific
{
   my($word) = @_;
   #my($newword);

   # antoine simplify and allow parentheses or quotes before the honorific (for "Dr. AAA")
   return ($word =~ /^($open_parenthesis|$quote)*$honorifics$/);
   # foreach $newword (@honorifics)
   # {
   #    if ($newword eq $word)
   #    {
   #       return 1;      # 1 means true
   #    }
   # }
   # return 0;            # 0 means false
}
# antoine add
sub IsNumPrefix
{
   my($word) = @_;

   return ($word =~ /^($open_parenthesis|$quote)*$num_prefix$/);
}

# This subroutine checks to see if the string is a terminal abbreviation.
sub IsTerminal
{
   my($word) = @_;
   my($newword);
   my(@terminals) = ("Esq", "Jr", "Sr", "M.D");

   foreach $newword (@terminals)
   {
      if ($newword eq $word)
      {
         return 1;      # 1 means true
      }
   }
   return 0;            # 0 means false
}

# This subroutine checks if the string is a standard representation of a U.S.
# timezone
sub IsTimeZone
{
   my($word) = @_;

   $word = substr($word,0,3);
   if ($word eq "EDT" || $word eq "CST" || $word eq "EST")
   {
      return 1;
   }
   else
   {
      return 0;
   }
}

# This subroutine checks to see if the input word ends in a closing double
# quote.
sub EndsInQuote
{
   my($word) = @_;

   # antoine. simplify
   return ($word =~ /$close_quote$/);
   # if (substr($word,-2,2) eq "''" || substr($word,-1,1) eq "'" ||
   #       substr($word, -3, 3) eq "'''" || substr($word,-1,1) eq "\""
   #       || substr($word, -2,2) eq "'\"")
   # {
   #    return 1;         # 1 means true
   # }
   # else
   # {
   #    return 0;         # 0 means false
   # }
}

# This subroutine checks to see if a given word starts with one or more quotes
sub StartsWithQuote
{
   my($word) = @_;

   # antoine. simplify
   return ($word =~ /^$quote/);
   # if (substr($word,0,1) eq "'" ||  substr($word,0,1) eq "\"" ||
   #       substr($word, 0, 1) eq "`")
   # {
   #    return 1;         # 1 means true
   # }
   # else
   # {
   #    return 0;         # 0 means false
   # }
}

# This subroutine checks to see if a word starts with a left parenthesis, be it
# {, ( or <
sub StartsWithLeftParen
{
   my($word) = @_;

   # antoine. simplify
   return ($word =~ /^$open_parenthesis/);
   # if (substr($word,0,1) eq "{" || substr($word,0,1) eq "("
   #       || substr($word,0,5) eq "-LBR-")
   # {
   #    return 1;         # 1 means true
   # }
   # else
   # {
   #    return 0;         # 0 means false
   # }
}

# This subroutine checks to see if a word starts with a left quote, be it
# `, ", "`, `` or ```
sub StartsWithLeftQuote
{
   my($word) = @_;

   # antoine. simplify
   return ($word =~ /^$open_quote/);
   # if (substr($word,0,1) eq "`" || substr($word,0,1) eq "\""
   #       || substr($word,0,2) eq "\"`")
   # {
   #    return 1;         # 1 means true
   # }
   # else
   # {
   #    return 0;         # 0 means false
   # }
}


sub IsRightEnd
{
   my($word) = @_;

   if (IsRightParen($word) || IsRightQuote($word))
   {
      return 1;
   }
   else
   {
      return 0;
   }
}

# This subroutine detects if a word starts with a start mark.
sub IsLeftStart
{
   my($word) = @_;

   if(StartsWithLeftQuote($word) || StartsWithLeftParen($word)
         || Capital($word) eq "Y")
   {
      return 1;
   }
   else
   {
      return 0;
   }
}

# This subroutine checks to see if a word is a right parenthesis, be it ), }
# or >
sub IsRightParen
{
   my($word) = @_;

   # antoine. simplify
   return ($word =~ /^$close_parenthesis$/);
   # if ($word eq "}" ||  $word eq ")" || $word eq "-RBR-")
   # {
   #    return 1;         # 1 means true
   # }
   # else
   # {
   #    return 0;         # 0 means false
   # }
}

sub IsRightQuote
{
   my($word) = @_;

   # antoine. simplify
   return ($word =~ /^$close_quote$/);
   # if ($word eq "'" ||  $word eq "''" || $word eq "'''" || $word eq "\""
   #       || $word eq "'\"")
   # {
   #    return 1;         # 1 means true
   # }
   # else
   # {
   #    return 0;         # 0 means false
   # }
}

# antoine add 
# preprocessing subrouting
sub AddSpaceAfterPunct
{
    my ($str) = @_;
    # add space after "." following anything but capital letters and numbers, 
    # and followed by a Capital letter or number
    #$$str =~ s/(?<![A-Z0-9])\.(?=([A-Z0-9])(?![^(]*\)))/. /g;
    #$$str =~ s/(?<![A-Z0-9])\.(?=[A-Z0-9])/. /g;
    $$str =~ s/(?<![A-Z0-9])\.(?=[A-Z0-9])/. /g;
    $$str =~ s/(?<=[0-9])\.(?=[a-zA-Z])/. /g;
    #$$str =~ s/;(?=.[^(]*\))/; /g;
    $$str =~ s/;/; /g;
    # add space after "," outside parentheses but not on "2,000" or "Cr,Nd doped gadolinium"
    #$$str =~ s/,(?!([A-Z0-9]|[^(]*\)))/, /g;
    $$str =~ s/,(?![A-Z0-9])/, /g;

}
sub AddSpaceToParentheses
{
    my ($str) = @_;
    $$str =~ s/(?<=[a-z])\(/ (/g;
    $$str =~ s/\)(?=[a-z])/) /g;
}
sub RemoveSpaceBeforePunct
{
    my ($str) = @_;
    $$str =~ s/ ,/,/g;
    $$str =~ s/ \.(?=[A-Z 0-9])/./g;
    $$str =~ s/ \.$/./g;
    # $$str =~ s/(?<=[0-9])\. (?=[0-9])/./g;
    # $$str =~ s/(?<=[0-9]) (?=[0-9])//g;
}
sub RemoveSpacesFromAbbreviations
{
    my ($str) = @_;
    $$str =~ s/i *\. *e *\./i.e./g;
    $$str =~ s/e *\. *g *\./e.g./g;
    $$str =~ s/L *\. *A *\./L.A./g;
    $$str =~ s/U *\. *K *\./U.K./g;
    $$str =~ s/U *\. *S *\./U.S./g;
    $$str =~ s/U *\. *S *\. *A *\./U.S.A./g;
}

1;
