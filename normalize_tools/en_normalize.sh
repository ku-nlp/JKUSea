#!/bin/sh

cat $* | \
./zen2han.pl | \
./en_tokenize.pl |\
./lowercase.sh |\
./en_lemmatize.pl
