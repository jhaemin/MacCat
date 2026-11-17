#!/usr/bin/env python3
"""Add a signed release to Sparkle's feed after its download is published."""
import base64
import datetime
import email.utils
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

version, build, signature, english, korean = sys.argv[1:]
if not re.fullmatch(r'\d+\.\d+\.\d+', version) or not build.isdecimal():
    raise SystemExit('Expected a semantic release version and numeric build')
ns = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', ns)
attrs = ET.fromstring(f'<enclosure xmlns:sparkle="{ns}" {signature}/>').attrib
if len(base64.b64decode(attrs[f'{{{ns}}}edSignature'], validate=True)) != 64 or int(attrs['length']) <= 0:
    raise SystemExit('Invalid Sparkle signature or archive length')
path = pathlib.Path(__file__).resolve().parent.parent / 'appcast.xml'
tree = ET.parse(path)
channel = tree.getroot().find('channel')
for previous in channel.findall('item'):
    if previous.findtext(f'{{{ns}}}shortVersionString') == version:
        channel.remove(previous)
item = ET.Element('item')
ET.SubElement(item, 'title').text = f'MacCat v{version}'
ET.SubElement(item, 'link').text = f'https://github.com/jhaemin/MacCat/releases/tag/v{version}'
ET.SubElement(item, 'pubDate').text = email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc))
for language, notes in [('en', english), ('ko', korean)]:
    ET.SubElement(item, 'description', {'{http://www.w3.org/XML/1998/namespace}lang': language}).text = pathlib.Path(notes).read_text()
ET.SubElement(item, f'{{{ns}}}version').text = build
ET.SubElement(item, f'{{{ns}}}shortVersionString').text = version
ET.SubElement(item, f'{{{ns}}}minimumSystemVersion').text = '14.0'
ET.SubElement(item, 'enclosure', {
    'url': f'https://github.com/jhaemin/MacCat/releases/download/v{version}/MacCat.zip',
    **attrs, 'type': 'application/octet-stream'
})
channel.insert(4, item)
ET.indent(tree, space='  ')
tree.write(path, encoding='utf-8', xml_declaration=True)
print(f'Added MacCat v{version} (build {build}) to appcast.xml')
