#!/usr/bin/env python3
"""Replace hard-coded English UI strings with locale lookups.

Each replacement becomes {{ t.<key> | default: "<English>" }}, so a site
without _data/locale/<lang>.yml renders exactly as before. The file also
gets `{%- assign t = site.data.locale[site.lang] -%}` at its top.
Idempotent: strings already replaced are skipped.
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSIGN = '{%- assign t = site.data.locale[site.lang] -%}\n'

# file -> list of (exact old text, key, English default)
# - ">Text<" text nodes and attr="Text" attributes become {{ t.key | default: "Text" }}
# - RAW entries (key, exact HTML) become {% if t.key %}{{ t.key }}{% else %}HTML{% endif %},
#   for text containing markup or quotes
R = {
    '_layouts/search.html': [
        ('>Search Options<', 'search_options', 'Search Options'),
        ('>Lunr Search Options<', 'search_options', 'Search Options'),
        ('placeholder="Enter your search term..."', 'search_placeholder', 'Enter your search term...'),
        ('aria-label="Search terms"', 'search_terms', 'Search terms'),
    ],
    '_includes/nav-search-lunr.html': [
        ('placeholder="Search"', 'search', 'Search'),
        ('aria-label="Search collection items"', 'search_collection_items', 'Search collection items'),
    ],
    '_includes/item/breadcrumbs.html': [
        ('>Home<', 'home', 'Home'),
        ('>Items<', 'items', 'Items'),
    ],
    '_includes/item/citation-box.html': [
        ('>Attribution<', 'attribution', 'Attribution'),
        ('<dt>Citation:</dt>', 'citation', 'Citation:'),
    ],
    '_includes/item/rights-box.html': [
        ('>Rights<', 'rights', 'Rights'),
        ('>Rights:<', 'rights_label', 'Rights:'),
        ('>Standardized Rights:<', 'rights_standardized', 'Standardized Rights:'),
    ],
    '_includes/item/browse-buttons.html': [
        ('>&laquo; Previous<', 'previous', '&laquo; Previous'),
        ('>Back to Browse<', 'back_to_browse', 'Back to Browse'),
        ('>Next &raquo;<', 'next', 'Next &raquo;'),
    ],
    '_layouts/item/item-page-base.html': [
        ('>Item Info \n', 'item_info', 'Item Info'),
        ('aria-label="Jump to Item Info"', 'jump_to_item_info', 'Jump to Item Info'),
    ],
    '_layouts/browse.html': [
        ('placeholder="Filter ... "', 'filter_placeholder', 'Filter ... '),
        ('>All Fields<', 'all_fields', 'All Fields'),
        ('>Title<', 'title', 'Title'),
        ('>Content Type<', 'content_type', 'Content Type'),
        ('>Advanced Search...<', 'advanced_search', 'Advanced Search...'),
        ('>Search<', 'search', 'Search'),
        ('>Reset<', 'reset', 'Reset'),
        ('>Random<', 'random', 'Random'),
        ('placeholder="Start Date"', 'start_date', 'Start Date'),
        ('placeholder="End Date"', 'end_date', 'End Date'),
        ('>Loading...<', 'loading', 'Loading...'),
    ],
    '_includes/footer.html': [
        ('>Last updated ', 'last_updated', 'Last updated'),
    ],
    '_includes/advanced-search-modal.html': [
        ('>Advanced Search<', 'advanced_search_title', 'Advanced Search'),
        ('>Close<', 'close', 'Close'),
        ('>Search<', 'search', 'Search'),
        ('>All Fields<', 'all_fields', 'All Fields'),
        ('>Title<', 'title', 'Title'),
        ('aria-label="Remove condition"', 'remove_condition', 'Remove condition'),
        ('placeholder="Enter search term"', 'enter_search_term', 'Enter search term'),
        ('aria-label="Search term"', 'search_terms', 'Search term'),
    ],
    '_includes/data-download-modal.html': [
        ('>Download Data<', 'download_data', 'Download Data'),
        ('>Collection Data<', 'collection_data', 'Collection Data'),
        ('>Complete Metadata<', 'dl_complete', 'Complete Metadata'),
        ('>Metadata Facets<', 'dl_facets', 'Metadata Facets'),
        ('>Timeline<', 'timeline', 'Timeline'),
        ('>Website Source Code<', 'dl_source', 'Website Source Code'),
        ('>Source Code<', 'source_code', 'Source Code'),
        ('aria-label="Close"', 'close', 'Close'),
    ],
    '_includes/scroll-to-top.html': [
        ('title="Back to Top"', 'back_to_top', 'Back to Top'),
        ('>Back to top<', 'back_to_top', 'Back to Top'),
    ],
    '_includes/collection-banner.html': [
        ('>Featured Image<', 'featured_image', 'Featured Image'),
    ],
    '_includes/js/browse-js.html': [
        ('>View Full Record<', 'view_full_record', 'View Full Record'),
    ],
}


RAW = {
    '_includes/data-download-modal.html': [
        ('dl_complete_desc', 'All metadata fields for all collection items, available as a CSV spreadsheet (usable in Excel, Google Sheets, and similar programs) or JSON file (often used with web applications).'),
        ('dl_facets_desc', 'List of unique values and their count for specific metadata fields, useful for understanding content of the fields.'),
        ('dl_timeline_desc', 'A time-focused JSON data export designed for use with <a href="https://timeline.knightlab.com/">TimelineJS</a>.'),
        ('dl_source_desc', 'GitHub repository containing source code for this project built with <a href="https://github.com/CollectionBuilder/collectionbuilder-csv">CollectionBuilder-CSV</a>.'),
        ('dl_intro', "Download this collection's data in a variety of reusable formats."),
    ],
    '_includes/advanced-search-modal.html': [
        ('add_another_field', 'Add Another Field'),
    ],
    '_layouts/about.html': [
        ('toc_title', '\n                    Contents\n'),
    ],
}


def sub(old, key, default):
    lookup = '{{ t.%s | default: "%s" }}' % (key, default.replace('"', '&quot;'))
    if old.startswith('>') and old.endswith('<'):
        return '>' + lookup + '<'
    if old.startswith('>') and old.endswith(' \n'):
        return '>' + lookup + ' \n'
    if old.startswith('>') and old.endswith(' '):
        return '>' + lookup + ' '
    if old.startswith('<dt>'):
        return '<dt>' + lookup + '</dt>'
    m = re.match(r'^([\w-]+)="', old)
    if m:
        return '%s="%s"' % (m.group(1), lookup)
    raise ValueError(old)


for path in sorted(set(R) | set(RAW)):
    reps = R.get(path, [])
    p = os.path.join(ROOT, path)
    s = open(p, encoding='utf-8').read()
    n = 0
    for key, html in RAW.get(path, []):
        wrapped = '{%% if t.%s %%}{{ t.%s }}{%% else %%}%s{%% endif %%}' % (key, key, html)
        if wrapped not in s and html in s:
            s = s.replace(html, wrapped)
            n += 1
    for old, key, default in reps:
        if old in s:
            s = s.replace(old, sub(old, key, default))
            n += 1
    if n and ASSIGN.strip() not in s:
        if s.startswith('---\n'):
            end = s.index('\n---\n', 4) + 5
            s = s[:end] + ASSIGN + s[end:]
        else:
            s = ASSIGN + s
    open(p, 'w', encoding='utf-8').write(s)
    print(f'{path}: {n} replaced')
