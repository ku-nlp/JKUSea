#!/usr/bin/env zsh

[ $# -ne 1 ] && { 
    echo "Usage: ./format_dictionary_EJ [input dictionary file name]  > [output file]" 
    echo "input dictionary file format:"
    echo "    tsv translation key value pairs."
    echo "    duplicate keys are allowed, e.g."
    echo "    en-expr1 ja-expr1"
    echo "    en-expr2 ja-expr2-1"
    echo "    en-expr3 ja-expr3"
    echo "    en-expr2 ja-expr2-2"
    exit 1;
}

ej="$1"
bej=$(basename $ej)

# converters
en_lemmatizer=../normalize_tools/en_lemmatize.pl
asciier=../normalize_tools/zen2han.pl
merger_oneline=./merge-keyvalues-file_oneline.pl

echo "1/6 extract en and ja columns" >&2
cut -f1 "${ej}" > "${bej}_en"
cut -f2 "${ej}" > "${bej}_ja"

echo "2/6 lemmatize English" >&2
$en_lemmatizer < "${bej}_en" > "${bej}_en_lem"

echo "3/6 lemmatize Japanese" >&2
cat "${bej}_ja" | juman | ../utils/jmn2base | sed -e 's/ //g' > "${bej}_ja_lem"

echo "4/6 merge back lemmatized English and Japanese into EJ dict" >&2
paste "${bej}_en_lem" "${bej}_ja_lem" > "${bej}_lem"

echo "5/6 convert UTF8 symbols, punctuations, alphanumeric characters to ascii" >&2
$asciier < "${bej}_lem" > "${bej}_lem_asciied"

echo "6/6 merge entries with the same key on one line" >&2
$merger_oneline < "${bej}_lem_asciied"

echo "remove tmp files (comment out to check intermediate results)" >&2
rm -f "${bej}_lem" "${bej}_ja" "${bej}_en" "${bej}_ja_lem" "${bej}_en_lem" "${bej}_lem_asciied"

