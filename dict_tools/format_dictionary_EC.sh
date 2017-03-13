#!/usr/bin/env zsh

[ $# -ne 1 ] && { 
    echo "Usage: ./format_dictionary_EC [input dictionary file name] > [output file]" 
    echo "input dictionary file format:"
    echo "    tsv translation key value pairs."
    echo "    duplicate keys are allowed, e.g."
    echo "    en-expr1 zh-expr1"
    echo "    en-expr2 zh-expr2-1"
    echo "    en-expr3 zh-expr3"
    echo "    en-expr2 zh-expr2-2"
    exit 1;
}

ec="$1"
bec=$(basename $ec)

# converters
en_lemmatizer=../normalize_tools/en_lemmatize.pl
asciier=../normalize_tools/zen2han.pl
merger_oneline=./merge-keyvalues-file_oneline.pl

echo "1/5 extract en and zh columns" >&2
cut -f1 "${ec}" > "${bec}_en"
cut -f2 "${ec}" > "${bec}_zh"

echo "2/5 lemmatize English" >&2
$en_lemmatizer < "${bec}_en" > "${bec}_en_lem"

echo "3/5 merge back lemmatized English and Chinese into EC dict" >&2
paste "${bec}_en_lem" "${bec}_zh" > "${bec}_lem"

echo "4/5 convert UTF8 symbols, punctuations, alphanumeric characters to ascii" >&2
$asciier < "${bec}_lem" > "${bec}_lem_asciied"

echo "5/5 merge entries with the same key on one line" >&2
$merger_oneline < "${bec}_lem_asciied" 

echo "remove tmp files (comment out to check intermediate results)" >&2
rm -f "${bec}_lem" "${bec}_zh" "${bec}_en" "${bec}_zh_lem" "${bec}_en_lem" "${bec}_lem_asciied"

