#!/usr/bin/env zsh

[ $# -ne 1 ] && { 
    echo "Usage: ./format_dictionary_CJ [input dictionary file name] > [output file]" 
    echo "input dictionary file format:"
    echo "    tsv translation key value pairs."
    echo "    duplicate keys are allowed, e.g."
    echo "    zh-expr1 ja-expr1"
    echo "    zh-expr2 ja-expr2-1"
    echo "    zh-expr3 ja-expr3"
    echo "    zh-expr2 ja-expr2-2"
    exit 1;
}

cj="$1"
bcj=$(basename $cj)

# converters
asciier=../normalize_tools/zen2han.pl
merger_oneline=./merge-keyvalues-file_oneline.pl

echo "1/5 extract zh and ja columns" >&2
cut -f1 "${cj}" > "${bcj}_zh"
cut -f2 "${cj}" > "${bcj}_ja"

echo "2/5 lemmatize Japanese" >&2
juman_version=$(juman -v 2>&1)
if [[ $juman_version =~ "juman 8" ]]; then
    cat "${bcj}_ja" | juman -g | sed -e 's/ //g' > "${bcj}_ja_lem"
elif [[ $juman_version =~ "juman 7" ]]; then
    cat "${bcj}_ja" | juman | ../utils/jmn2base | sed -e 's/ //g' > "${bcj}_ja_lem"
else
    echo "Fatal error: Unrecognized version of Juman."
    exit 1
fi

echo "3/5 merge back lemmatized Japanese into CJ dict" >&2
paste "${bcj}_zh" "${bcj}_ja_lem" > "${bcj}_lem"

echo "4/5 convert UTF8 symbols, punctuations, alphanumeric characters to ascii" >&2
$asciier < "${bcj}_lem" > "${bcj}_lem_asciied"

echo "5/5 merge entries with the same key on one line" >&2
$merger_oneline < "${bcj}_lem_asciied"

echo "remove tmp files (comment out to check intermediate results)" >&2
rm -f "${bcj}_ja" "${bcj}_zh" "${bcj}_lem" "${bcj}_ja_lem" "${bcj}_lem_asciied"
