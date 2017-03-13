#!/usr/bin/env python

import xml.etree.ElementTree

rootElement = xml.etree.ElementTree.parse('../dict/JMdict_e.xml')
for entry in rootElement.findall('entry'):
    en_word = None
    ja_word = None

    kEleElement = entry.find('k_ele')
    if kEleElement is not None:
        kebElement = kEleElement.find('keb')
        if kebElement is not None:
            ja_word = kebElement.text

    if ja_word is None:
        rEleElement = entry.find('r_ele')
        if rEleElement is not None:
            rebElement = rEleElement.find('reb')
            if rebElement is not None:
                ja_word = rebElement.text

    senseElement = entry.find('sense')
    if senseElement is not None:
        glossElement = senseElement.find('gloss')
        if glossElement is not None:
            en_word = glossElement.text

    if ja_word is not None and en_word is not None:
        print("{0}\t{1}".format(en_word.encode('utf-8'), ja_word.encode('utf-8')))
