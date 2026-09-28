#!/usr/bin/env python3
"""Add a few locally hosted image items to _data/utokyo-agri.csv.

The rest of the demo shows images from the University of Tokyo's IIIF server.
These rows instead point at JPEG files in objects/, the way most
CollectionBuilder sites work, so the static IIIF output (manifests and the
optional Level 0 image service) has something to publish.

1. Downloads the images once from the UTokyo IIIF Image API into objects/
   (CC BY 4.0, University Library for Agricultural and Life Sciences).
2. Makes CB's usual derivatives (objects/small/*_sm.jpg, objects/thumbs/*_th.jpg)
   with libvips, matching rakelib/generate_derivatives.rake's names and sizes.
3. Rewrites the local_* rows of the CSV (idempotent) and adds a parentid column.

Requires: vips (brew install vips).
"""
import csv
import os
import subprocess
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV = os.path.join(ROOT, '_data', 'utokyo-agri.csv')
OBJ = os.path.join(ROOT, 'objects')
REFERER = 'https://nakamura196.github.io/'  # the server refuses http:// referers

# (source item, new objectid, template, [(image service, width to download)])
# 'iiif' shows the item in Universal Viewer from the manifest this site generates,
# like the other items; 'image' / 'compound_object' would use CB's own galleries.
SAMPLES = [
    ('agri_187cc82d', 'local_chokanzu', 'iiif', [
        ('https://iiif.dl.itc.u-tokyo.ac.jp/iiif/agriculture_re/nou_tatemonochokanzu/0002.tif', 6000),
    ]),
    ('agri_97a6ecb3', 'local_gunpo09', 'iiif', [
        ('https://iiif.dl.itc.u-tokyo.ac.jp/iiif/agri_waso20201006_re/13_gunbozuhu_09/%03d.tif' % i, 2400)
        for i in range(1, 10)
    ]),
]


def fetch(service, width, dest):
    if os.path.exists(dest):
        return
    url = f'{service}/full/{width},/0/default.jpg'
    req = urllib.request.Request(url, headers={'Referer': REFERER, 'User-Agent': 'cb-ja-demo'})
    with urllib.request.urlopen(req, timeout=120) as r, open(dest, 'wb') as f:
        f.write(r.read())
    print('downloaded', os.path.relpath(dest, ROOT))


def derivatives(src, name):
    out = {}
    for sub, suffix, size in (('small', 'sm', '800x800'), ('thumbs', 'th', '450x')):
        os.makedirs(os.path.join(OBJ, sub), exist_ok=True)
        dest = os.path.join(OBJ, sub, f'{name}_{suffix}.jpg')
        if not os.path.exists(dest):
            w, _, h = size.partition('x')
            args = ['vipsthumbnail', src, '--size', f'{w}x{h}' if h else w, '-o', dest + '[Q=85,strip]']
            subprocess.run(args, check=True)
        out[sub] = '/objects/' + sub + '/' + os.path.basename(dest)
    return out


def main():
    with open(CSV, encoding='utf-8') as f:
        reader = csv.DictReader(f)
        fields = list(reader.fieldnames)
        rows = [r for r in reader if not r['objectid'].startswith('local_')]
    if 'parentid' not in fields:
        fields.insert(1, 'parentid')
    by_id = {r['objectid']: r for r in rows}

    new = []
    for src_id, oid, template, images in SAMPLES:
        src = by_id[src_id]
        base = {k: src.get(k, '') for k in fields}
        base.update(objectid=oid, parentid='', manifest='', format='image/jpeg',
                    display_template=template, pages=str(len(images)),
                    title=src['title'] + '（手元の画像から配信）')
        children = []
        for i, (service, width) in enumerate(images, 1):
            name = oid if len(images) == 1 else f'{oid}_{i:02d}'
            path = os.path.join(OBJ, name + '.jpg')
            fetch(service, width, path)
            d = derivatives(path, name)
            loc = dict(object_location=f'/objects/{name}.jpg', image_small=d['small'], image_thumb=d['thumbs'])
            if len(images) == 1:
                base.update(loc)
            else:
                child = {k: '' for k in fields}
                child.update(loc, objectid=name, parentid=oid, title=f'{src["title"]} 第{i}コマ',
                             format='image/jpeg', display_template='image', rights=src['rights'],
                             rightsstatement=src['rightsstatement'], image_alt_text=f'{src["title"]} 第{i}コマ')
                if 'group' in fields:  # holding-library group used by the browse facets
                    child['group'] = src.get('group', '')
                children.append(child)
        if children:  # the parent uses its first page as the representative image
            base.update(image_small=children[0]['image_small'], image_thumb=children[0]['image_thumb'],
                        object_location='')
        new += [base] + children

    with open(CSV, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows + new)
    print(f'wrote {len(rows)} + {len(new)} local rows -> {os.path.relpath(CSV, ROOT)}')


if __name__ == '__main__':
    main()
