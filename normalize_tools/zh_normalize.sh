#!/bin/bash

SCRIPTPATH="$( dirname "$0" )"
$SCRIPTPATH/zen2han.pl | $SCRIPTPATH/lowercase.sh
