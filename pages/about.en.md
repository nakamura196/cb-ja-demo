---
# English version; inherits the rest of the front matter from the default page (_plugins/cb_i18n.rb)
title: About
permalink: /about.html
lang: en
heading: About
---

## The collection

Three groups of items whose IIIF images are published on the [University of Tokyo Digital Archives Portal](https://da.dl.itc.u-tokyo.ac.jp/portal/), chosen to test Japanese, Chinese (Classical Chinese) and Korean search on real material.

- **34 rare books from the Library for Agricultural and Life Sciences.** Botanical atlases such as *Yūyō shokubutsu zusetsu* (有用植物圖説), *Gunpō fu* (群芳圖譜) and *Nihon shinrin jumoku zufu* (日本森林樹木図譜), mulberry-leaf specimen books, and a 1937 bird's-eye view of the Hongo campus. Most titles use older character forms.
- **12 volumes of the Annals of the Joseon Dynasty** (朝鮮王朝実録), four each from the reigns of Seongjong, Jungjong and Seonjo. The text is Classical Chinese. Formerly held by the University of Tokyo General Library, they were donated to Seoul National University in 2006; the portal lists the Kyujanggak Institute for Korean Studies as the holder.
- **12 Korean-language items from the Ogura Collection** (小倉文庫), held by the Department of Linguistics, Faculty of Letters, and digitized by the Research Institute for Languages and Cultures of Asia and Africa, Tokyo University of Foreign Studies. Five have hangul titles; others are *eonhae* (諺解), Classical Chinese texts with a hangul translation.

Images and bibliographic records are loaded directly from the University of Tokyo Digital Archives; this site keeps no copies of the images.
Items were found through the [Japan Search](https://jpsearch.go.jp/) API, and the catalogue was built from the Archives' records (DC-NDL).
Terms of use are shown on each item page (CC BY 4.0 for the Agricultural Library and the Ogura Collection, CC0 for the Annals).
Titles and descriptions are kept in their original languages.

{% include feature/button.html text="Catalogue data (CSV)" link="/assets/data/metadata.csv" color="outline-dark" %}

## What this demo adds to CollectionBuilder

[CollectionBuilder-CSV](https://github.com/CollectionBuilder/collectionbuilder-csv) builds a digital collection website from a spreadsheet catalogue.
It is widely used by libraries and archives in the English-speaking world, but it does not work well for Japanese, Chinese or Korean material out of the box.
This demo adds four things without changing how CollectionBuilder works.

**1. CJK search**

The original search strips kanji and kana during English-oriented pre-processing, so even an exact title returns 0 results.
This demo indexes text in two-character pieces together with their order.
Old and new character forms (圖/図), Traditional and Simplified Chinese (實錄/实录), katakana and hiragana, and full- and half-width characters are treated as the same.
Korean (hangul) is searched the same way.
The index is built when the site is generated, by the Ruby gem [cjk_index](https://github.com/nakamura196/cjk_index), so the browser only has to run the search.
[The search comparison](compare.html) puts the two side by side.

**2. Switchable interface language**

Button and heading text lives in `_data/locale/<lang>.yml`, and labels from the configuration spreadsheets (field and menu names) can be overridden per language.
The same repository builds this English site and the Japanese site; the link at the top right switches between them.
Without a language file, the site shows the original English text.

**3. IIIF items displayed as they are**

Put a IIIF manifest URL in the `manifest` column and the item page opens it in Universal Viewer, with a link to open it in Mirador.
The catalogue itself is generated from IIIF manifests and bibliographic records (`_tools/utokyo_agri.py`).

**4. A replaceable theme**

The museum-style look (serif headings, generous white space) is made with added CSS only; the core templates are unchanged.

## Not done yet

- Proposals (pull requests) to bring these changes into CollectionBuilder
- User guides in Japanese and English

## Credits

This site is built on [CollectionBuilder-CSV](https://collectionbuilder.github.io/) (University of Idaho Library, Center for Digital Inquiry and Learning).
Images and records are from the University of Tokyo Digital Archives Portal.
The originals are held by the University of Tokyo Library for Agricultural and Life Sciences, the Kyujanggak Institute for Korean Studies, Seoul National University (Annals of the Joseon Dynasty, formerly University of Tokyo General Library), and the Department of Linguistics, Graduate School of Humanities and Sociology / Faculty of Letters, University of Tokyo (Ogura Collection).
