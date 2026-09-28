---
title: About
layout: about
permalink: /about.html
# include CollectionBuilder info at bottom
credits: false
about-featured-image: agri_2c310bb0
position: center
heading: About
sub-heading:
padding: 6em
lang: en
---

## The collection

Rare books from the University of Tokyo Library for Agricultural and Life Sciences: the 34 items whose IIIF images are published on the [University of Tokyo Digital Archives Portal](https://da.dl.itc.u-tokyo.ac.jp/portal/collection/agriculture).
They include botanical atlases such as *Yūyō shokubutsu zusetsu* (有用植物圖説), *Gunpō fu* (群芳圖譜) and *Nihon shinrin jumoku zufu* (日本森林樹木図譜), mulberry-leaf specimen books, and a 1937 bird's-eye view of the Hongo campus.

Images and bibliographic records are loaded directly from the University of Tokyo Digital Archives; this site keeps no copies of the images.
Items were found through the [Japan Search](https://jpsearch.go.jp/) API, and the catalogue was built from the Archives' records (DC-NDL).
Each item is available under CC BY 4.0, as shown on its page.
Titles and descriptions are kept in the original Japanese.

{% include feature/button.html text="Catalogue data (CSV)" link="/assets/data/metadata.csv" color="outline-dark" %}

## What this demo adds to CollectionBuilder

[CollectionBuilder-CSV](https://github.com/CollectionBuilder/collectionbuilder-csv) builds a digital collection website from a spreadsheet catalogue.
It is widely used by libraries and archives in the English-speaking world, but it does not work well for Japanese material out of the box.
This demo adds four things without changing how CollectionBuilder works.

**1. Japanese search**

The original search strips kanji and kana during English-oriented pre-processing, so even an exact title returns 0 results.
This demo indexes text in overlapping two-character pieces and treats old and new character forms (圖/図), katakana and hiragana, and full- and half-width characters as the same.
[The search comparison](compare.html) puts the two side by side.

**2. Switchable interface language**

Button and heading text lives in `_data/locale/<lang>.yml`, and labels from the configuration spreadsheets can be overridden per language.
The same repository builds this English site and the Japanese site; the link at the top right switches between them.
Without a language file, the site shows the original English text.

**3. IIIF items displayed as they are**

Put a IIIF manifest URL in the `manifest` column and the item page opens it in Universal Viewer, with a link to open it in Mirador.
The catalogue itself is generated from IIIF manifests and bibliographic records (`_tools/utokyo_agri.py`).

**4. A replaceable theme**

The museum-style look (serif headings, generous white space) is made with added CSS only; the core templates are unchanged.

## Not done yet

- Checking with Chinese and Korean material
- Proposals (pull requests) to bring these changes into CollectionBuilder
- User guides in Japanese and English

## Credits

This site is built on [CollectionBuilder-CSV](https://collectionbuilder.github.io/) (University of Idaho Library, Center for Digital Inquiry and Learning).
Images and records are from the University of Tokyo Library for Agricultural and Life Sciences and the University of Tokyo Digital Archives Portal.
