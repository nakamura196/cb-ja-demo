---
# English version; inherits the rest of the front matter from the default page (_plugins/cb_i18n.rb)
title: Search comparison
permalink: /compare.html
lang: en
---

## Search comparison

The same catalogue of 58 items, searched two ways.

- **Original CollectionBuilder**: the built-in search (lunr with its default settings). Its English-oriented pre-processing treats kanji and kana as punctuation and strips them, so even an exact title returns 0 results.
- **CJK-ready**: the search added in this demo (the Ruby gem [cjk_index](https://github.com/nakamura196/cjk_index)). It indexes text in two-character pieces together with their order, so it finds words in the middle of a title exactly. Old and new character forms (圖/図), Traditional and Simplified Chinese (實錄/实录), katakana and hiragana, and full- and half-width characters are treated as the same. Korean (hangul) is searched the same way.

Try your own query in the box below.
