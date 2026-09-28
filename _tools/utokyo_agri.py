#!/usr/bin/env python3
"""Build the collection CSV from the UTokyo Digital Archive: East Asian materials.

Three groups, chosen to show search in Japanese, Chinese (kanbun) and Korean:
  agri      東京大学農学生命科学図書館 — all items with UTokyo images (34)
  jitsuroku 朝鮮王朝実録 (総合図書館旧蔵、現 ソウル大学校奎章閣) — four volumes per reign
  ogura     小倉文庫 [文学部言語学研究室] — hangul titles, then Korean-language books

What it does:
  1. Lists items via the Japan Search API (the portal's own search pages
     refuse scripted access).
  2. Fetches each item's metadata (?_format=json, DC-NDL) and IIIF manifest
     from da.dl.itc.u-tokyo.ac.jp, one request per second, cached in
     _tools/cache/ (git-ignored).
  3. Keeps items whose manifest has canvases (images hosted by UTokyo).
     Items digitised by NIJL have an empty UTokyo manifest; pass --with-nijl
     to include them as metadata-only records.
  4. Writes _data/utokyo-agri.csv in CollectionBuilder's column layout.
     (The file keeps its first name although it now holds all three groups.)
     Run _tools/local_sample.py afterwards to add the locally hosted rows.

Usage:
  python3 _tools/utokyo_agri.py            # uses cache, fetches what's missing
  python3 _tools/utokyo_agri.py --refresh  # re-fetch everything
"""
import argparse
import csv
import json
import os
import re
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, '_tools', 'cache')
OUT = os.path.join(ROOT, '_data', 'utokyo-agri.csv')
UA = {'User-Agent': 'collectionbuilder-ja-demo (research; github.com/nakamura196)'}
HANGUL = re.compile('[\uac00-\ud7af]')

# key: (objectid prefix, group label, Japan Search keyword, how many to keep)
SOURCES = {
    'agri': ('agri', '農学生命科学図書館', '東京大学農学生命科学図書館', None),
    'jitsuroku': ('jitsu', '朝鮮王朝実録', '朝鮮王朝実録', 12),
    'ogura': ('ogura', '小倉文庫（言語学研究室）', '小倉文庫', 12),
}
PORTAL = 'https://da.dl.itc.u-tokyo.ac.jp/portal'

MATERIAL = {
    'http://ndl.go.jp/ndltype/Book': '図書',
    'http://ndl.go.jp/ndltype/Map': '地図',
    'http://ndl.go.jp/ndltype/JapaneseClassicalBook': '和古書',
}
LICENSE = {
    'http://creativecommons.org/licenses/by/4.0/': 'CC BY 4.0',
    'https://creativecommons.org/publicdomain/zero/1.0/': 'CC0 1.0',
}

# Which canvas (0-based) to use as the item's representative image. The first
# canvas is usually the cover with a colour chart, so pick a plate instead.
# Chosen by eye from a contact sheet; anything not listed uses n // 4.
# All 34 checked frame by frame on 2026-09-28 (text-only volumes use the title
# page where there is one; the scroll and maps keep their colour charts).
CANVAS = {
    'd9115c2c': 11, '29d63e58': 12, '5bfde8bf': 11, '87c1c4a4': 1, '7844f0c7': 11,
    'bb4b00b5': 1, '42dfe305': 2, '6041ed83': 2, '627f6b5d': 5, '2c310bb0': 25,
    '70f02bc2': 21, 'f9dbea50': 22, 'c2466a42': 3, '9c79a3bb': 2, '58f3ea6c': 2,
    '3e6f484d': 42, 'a09fc5f4': 2, 'f3bfde97': 2, '4e17a945': 5, '8d83cc45': 3,
    'c9f1ab4e': 2, '05fc859e': 3, 'e443b3ea': 3, '2da73342': 10, '30c60644': 3,
    '0717b584': 3, 'a2af6812': 4, '97a6ecb3': 2, '6d032fb5': 3, '187cc82d': 1,
    'df8094b2': 3, 'b4814f58': 3, '7a3e0c92': 3, 'b6e42779': 3,
    # Annals and Ogura: all 24 checked on 2026-09-28. The Annals are text
    # throughout, so most keep n // 4; the seal leaves near the front are half
    # blank. Ogura covers are used where the title is written large on them.
    '8edec05c': 0, '0316e957': 8, '6d9db582': 3, '7eccfbd6': 4, 'bd881fb8': 16,
    'cbdf5a5b': 18, 'c19e66ca': 19, 'bec028c0': 20, 'b9892ce3': 9, '51ed985b': 8,
    'c37579e6': 12, '81c23003': 6,
    '4e4d1e44': 1, '6bc72db8': 0, '5f1ba74f': 12, '719c92aa': 1, '31e0f815': 0,
    '83a81497': 8, '60df1b75': 16, '5c1cb83b': 1, '0318bc68': 20, '5973c9c6': 19,
    'a02c8a34': 6, '42888882': 17,
}

FIELDS = [
    'objectid', 'title', 'title_kana', 'alternative', 'creator', 'date', 'year',
    'era', 'type', 'extent', 'call_number', 'description', 'note', 'collection',
    'holding', 'digitizer', 'pages', 'rights', 'rightsstatement', 'source',
    'manifest', 'viewing_direction', 'image_small', 'image_thumb',
    'object_location', 'image_alt_text', 'format', 'display_template', 'group',
]


def fetch(url, path, refresh=False, delay=1.0):
    if os.path.exists(path) and not refresh:
        return json.load(open(path, encoding='utf-8'))
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
            open(path, 'wb').write(data)
            time.sleep(delay)
            return json.loads(data)
        except Exception as e:  # noqa: BLE001 - report and retry
            print('  retry', url, e)
            time.sleep(5)
    raise RuntimeError('failed: ' + url)


def list_uuids(key, refresh):
    """UUIDs of UTokyo Digital Archive items found by the source's keyword."""
    keyword = SOURCES[key][2]
    q = urllib.parse.urlencode({'keyword': keyword, 'size': 500})
    data = fetch('https://jpsearch.go.jp/api/item/search/jps-cross?' + q,
                 os.path.join(CACHE, 'jpsearch.json' if key == 'agri' else f'jpsearch-{key}.json'), refresh)
    items = []
    for it in data['list']:
        if not it['id'].startswith('utokyo_da-'):
            continue
        if key == 'agri' and keyword not in (it['common'].get('provider') or ''):
            continue
        title = it['common'].get('title') or ''
        items.append((it['id'][len('utokyo_da-'):].replace('_', '-'), title if isinstance(title, str) else ' '.join(title)))
    # Narrow the larger groups by title before fetching anything per item.
    if key == 'ogura':
        # hangul titles first, then Korean-language books by their kanji titles
        # (諺解 = vernacular annotation, 諺文 = hangul, 韓語 / 朝鮮語)
        korean = re.compile('諺|韓語|朝鮮語')
        items = ([i for i in items if HANGUL.search(i[1])] +
                 sorted((i for i in items if not HANGUL.search(i[1]) and korean.search(i[1])), key=lambda i: i[1]))
    elif key == 'jitsuroku':
        per_reign = {}
        for uuid, title in sorted(items, key=lambda i: i[1]):
            reign = title.split(' ')[0]
            if len(per_reign.setdefault(reign, [])) < 4:  # four volumes per reign
                per_reign[reign].append((uuid, title))
        items = [i for vols in per_reign.values() for i in vols]
    return [uuid for uuid, _ in items]


def select(key, rows):
    """Keep a readable sample of the larger groups (already narrowed by title)."""
    limit = SOURCES[key][3]
    if key == 'ogura':
        rows = sorted(rows, key=lambda r: (not HANGUL.search(r['title']), r['title']))
    return rows[:limit] if limit else rows


def vals(meta, key, lang='ja'):
    """Return a list of string values for a DC-NDL key (prefers `lang`)."""
    v = meta.get(key)
    if v is None:
        return []
    if not isinstance(v, list):
        v = [v]
    out = []
    langs = {x.get('@language') for x in v if isinstance(x, dict)}
    for x in v:
        if isinstance(x, dict):
            if lang in langs and x.get('@language') not in (None, lang):
                continue
            s = x.get('@value') or x.get('@id')
        else:
            s = x
        if s:
            out.append(re.sub(r'\s+', ' ', str(s)).strip())
    return out


def era_of(year, key):
    if key != 'agri':
        return '朝鮮時代'
    if not year:
        return '年代不明'
    y = int(year)
    if y < 1868:
        return '江戸時代以前'
    if y < 1912:
        return '明治'
    if y < 1926:
        return '大正'
    if y < 1989:
        return '昭和'
    return '平成以降'


def row_for(key, uuid, meta, manifest):
    canvases = (manifest.get('sequences') or [{}])[0].get('canvases', [])
    title = vals(meta, 'dcterms:title')[0]
    issued = vals(meta, 'dcterms:issued')
    date = vals(meta, 'dcterms:date')
    year = issued[0][:4] if issued else ''
    if not year and date:
        m = re.search(r'(1[5-9]\d\d)', date[0])
        year = m.group(1) if m else ''

    call_number, description, notes = '', '', []
    for d in vals(meta, 'dcterms:description'):
        if d.startswith('請求記号：') or d.startswith('東大請求記号：'):
            call_number = d.split('：', 1)[1].strip()
        elif d.startswith('資料の解説'):
            description = re.sub(r'^資料の解説\s*[:：]\s*', '', d)
        else:
            notes.append(d)

    small = thumb = full = ''
    if canvases:
        pick = CANVAS.get(uuid.split('-')[0], len(canvases) // 4)
        svc = canvases[min(pick, len(canvases) - 1)]['images'][0]['resource'].get('service', {}).get('@id', '')
        if svc:
            small = svc + '/full/!1000,1000/0/default.jpg'
            thumb = svc + '/full/!400,400/0/default.jpg'
            full = svc + '/full/max/0/default.jpg'

    rights = vals(meta, 'dcterms:license') or vals(meta, 'dcterms:rights')
    return {
        'objectid': SOURCES[key][0] + '_' + uuid.split('-')[0],
        'title': title,
        'title_kana': ';'.join(vals(meta, 'dcndl:titleTranscription')),
        'alternative': ';'.join(a for a in vals(meta, 'dcndl:alternative') if a != title),
        'creator': ';'.join(vals(meta, 'dc:creator')),
        'date': ';'.join(date),
        'year': year,
        'era': era_of(year, key),
        'type': MATERIAL.get(meta.get('dcndl:materialType', {}).get('@id'), ''),
        'extent': ';'.join(vals(meta, 'dcterms:extent')),
        'call_number': call_number,
        'description': description,
        'note': ';'.join(notes),
        'collection': ';'.join(vals(meta, 'dcterms:isPartOf')),
        'holding': ';'.join(vals(meta, 'dcndl:holdingAgent')),
        'digitizer': ';'.join(vals(meta, 'dcndl:digitizedPublisher')),
        'pages': str(len(canvases)) if canvases else '',
        'rights': LICENSE.get(rights[0], rights[0]) if rights else '',
        'rightsstatement': rights[0] if rights else '',
        'source': f'{PORTAL}/assets/{uuid}',
        'manifest': manifest.get('@id', ''),
        'viewing_direction': manifest.get('viewingDirection', ''),
        'image_small': small,
        'image_thumb': thumb,
        'object_location': full,
        'image_alt_text': f'「{title}」の図版（{pick + 1}コマ目）' if small else '',
        'format': 'image/jpeg' if small else '',
        'display_template': 'iiif' if canvases else 'record',
        'group': SOURCES[key][1],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--refresh', action='store_true')
    ap.add_argument('--with-nijl', action='store_true',
                    help='also include NIJL-digitised items (no UTokyo images)')
    args = ap.parse_args()
    os.makedirs(CACHE, exist_ok=True)

    rows = []
    for key in SOURCES:
        found = []
        for uuid in list_uuids(key, args.refresh):
            meta = fetch(f'{PORTAL}/assets/{uuid}?_format=json',
                         os.path.join(CACHE, uuid + '.meta.json'), args.refresh)
            manifest = fetch(f'{PORTAL}/repo/iiif/{uuid}/manifest',
                             os.path.join(CACHE, uuid + '.manifest.json'), args.refresh)
            row = row_for(key, uuid, meta, manifest)
            if row['display_template'] == 'iiif' or (key == 'agri' and args.with_nijl):
                found.append(row)
        kept = select(key, found)
        print(f'{key}: {len(found)} with images, kept {len(kept)}')
        rows.extend(kept)

    ids = [r['objectid'] for r in rows]
    assert len(ids) == len(set(ids)), 'objectid collision'
    order = {v[1]: i for i, v in enumerate(SOURCES.values())}
    rows.sort(key=lambda r: (order[r['group']], r['year'] or '9999', r['title_kana'] or r['title']))
    with open(OUT, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)
    print(f'wrote {len(rows)} rows -> {os.path.relpath(OUT, ROOT)}')


if __name__ == '__main__':
    main()
