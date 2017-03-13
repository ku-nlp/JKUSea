#!/usr/bin/env python

import re

with open('../dict/cedict_ts.u8') as f:
    lines = f.readlines()

entry_regex = re.compile('(.*?) (.*?) \[(.*?)\] /(.*?)/')
for line in lines:
    result = entry_regex.match(line)
    if result:
        (traditional, simplified, pronunciations, english_meanings) = result.groups()
        if simplified is not None and english_meanings is not None:
            english_meanings = re.sub(r'\(.*\)', '', english_meanings)
            english_meanings = re.sub(r'lit\. ', '', english_meanings)
            if len(english_meanings) > 0:
                print "{0}\t{1}".format(english_meanings, simplified)
