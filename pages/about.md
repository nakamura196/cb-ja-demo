---
title: このサイトについて
layout: about
permalink: /about.html
# include CollectionBuilder info at bottom
credits: true
about-featured-image: agri_2c310bb0
position: center
heading: このサイトについて
sub-heading:
padding: 6em
---

## 収録資料

東京大学農学生命科学図書館の貴重書のうち、[東京大学デジタルアーカイブポータル](https://da.dl.itc.u-tokyo.ac.jp/portal/collection/agriculture)で IIIF 画像が公開されている 34 点です。
『有用植物圖説』『群芳圖譜』『日本森林樹木図譜』などの植物図譜、桑の葉の摺葉譜、昭和12年の本郷キャンパス鳥瞰図を含みます。

画像と書誌は東京大学デジタルアーカイブから直接読み込んでいます。
このサイトは画像を複製していません。
書誌データは [Japan Search](https://jpsearch.go.jp/) の API で資料を探し、東京大学デジタルアーカイブの書誌（DC-NDL 形式）から作りました。
利用条件は各資料のページに示したとおり（CC BY 4.0）です。

{% include feature/button.html text="目録データ（CSV）" link="/assets/data/metadata.csv" color="outline-dark" %}

## このデモで CollectionBuilder に加えたこと

[CollectionBuilder-CSV](https://github.com/CollectionBuilder/collectionbuilder-csv) は、表計算の目録から資料公開サイトを作る道具です。
英語圏の図書館・文書館で広く使われていますが、日本語の資料ではそのままでは使いにくい点があります。
このデモでは、本体の仕組みを崩さずに次の 4 点を加えました。

**1. 日本語で検索できるようにしました**

元の検索は、英語向けの前処理で漢字やかなを消してしまいます。
そのため、題名をそのまま入れても 0 件になります。
このデモでは文字を 2 字ずつに区切って索引を作り、旧字と新字（圖と図）、カタカナとひらがな、全角と半角を同じものとして扱います。
[検索の比較](compare.html)で、元の検索と並べて確かめられます。

**2. 画面の言葉を切り替えられるようにしました**

ボタンや見出しの言葉を `_data/locale/ja.yml` にまとめました。
言語ファイルが無い場合は、これまでどおり英語で表示されます。

**3. IIIF の資料をそのまま表示できるようにしました**

目録の `manifest` 欄に IIIF マニフェストの URL を入れると、資料のページに Universal Viewer が開きます。
Mirador で開くボタンも付けています。
目録そのものも、IIIF マニフェストと書誌から自動で作っています（`_tools/utokyo_agri.py`）。

**4. 見た目を差し替えられるテーマにしました**

明朝体の見出しと広い余白の「ミュージアム風」の見た目は、CSS の追加だけで作っています。
本体のテンプレートには手を入れていません。

## まだできていないこと

- 画面の言葉の翻訳は、主な画面だけです（全体で 180 か所以上あります）
- 中国語・韓国語での確認
- 本体に取り込んでもらうための提案（プルリクエスト）
- 利用者向けの手引き（日本語・英語）
