#!/usr/bin/env python3
"""Assemble index/menu/catering from _head/_header/_footer templates + _*.body files."""
import pathlib
root = pathlib.Path(__file__).resolve().parent
head = (root/'_head.tpl').read_text(); hdr = (root/'_header.tpl').read_text(); ftr = (root/'_footer.tpl').read_text()
pages = {
 'index.html': ('_index.body', 'Pinz Grill | Wings, Burgers & Patty Melts in Columbia, SC',
   'Fresh grilled wings, burgers, patty melts, pizza and more on Broad River Road in Columbia, SC. Order online for pickup.', '', ''),
 'menu.html': ('_menu.body', 'Menu | Pinz Grill',
   'Full Pinz Grill menu with prices: wings, tenders, burgers, hot dogs, pizza, sides, kids meals and party packs.', 'aria-current="page"', ''),
 'catering.html': ('_catering.body', 'Catering | Pinz Grill',
   'Catering in Columbia, SC: wing packages from 30 to 100, tenders, burgers, pizza and sides for events of any size.', '', 'aria-current="page"'),
 # The two pages the iPhone app's App Store listing points at. No concept banner
 # on these: a privacy policy that calls itself a concept reads as fake.
 'privacy.html': ('_privacy.body', 'Privacy Policy | Pinz Grill app',
   'What the Pinz Grill iPhone app does and does not do with your information.', '', ''),
 'support.html': ('_support.body', 'App Support | Pinz Grill',
   'Help with ordering, delivery, catering and the Pinz Grill iPhone app.', '', ''),
}
LEGAL = ('privacy.html', 'support.html')
for out, (body, title, desc, cm, cc) in pages.items():
    h = head.replace('__TITLE__', title).replace('__DESC__', desc)
    hd = hdr.replace('__CUR_MENU__', cm).replace('__CUR_CAT__', cc)
    foot = ftr.split('<div class="concept">')[0] if out in LEGAL else ftr
    html = '<!DOCTYPE html>\n<html lang="en">\n<head>\n' + h + '</head>\n<body>\n' + hd + (root/body).read_text() + foot + '</body>\n</html>\n'
    (root/out).write_text(html); print(out, len(html))
