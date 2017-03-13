#!/usr/bin/env zsh

juman_version=$(juman -v 2>&1)
if [[ $juman_version =~ "juman 8" ]]; then
    juman -g | sed -u -e 's/\\ / /g' | sed -u 's/ //g' | ./zen2han.pl | ./lowercase.sh
elif [[ $juman_version =~ "juman 7" ]]; then
    juman | ./juman2oneline.pl | ./zen2han.pl | ./lowercase.sh
else
    echo "Fatal error: Unrecognized version of Juman."
    exit 1
fi


