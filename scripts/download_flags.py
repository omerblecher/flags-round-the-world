"""Download flag SVGs from lipis/flag-icons for all 196 countries."""
import json
import urllib.request
import os
import time

ASSETS_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'flags')
COUNTRIES_JSON = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data', 'countries_en.json')
BASE_URL = 'https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/{code}.svg'

os.makedirs(ASSETS_DIR, exist_ok=True)

with open(COUNTRIES_JSON, encoding='utf-8') as f:
    countries = json.load(f)

iso_codes = list(countries.keys())
print(f'Downloading {len(iso_codes)} flags...')

failed = []
for i, code in enumerate(iso_codes):
    dest = os.path.join(ASSETS_DIR, f'{code}.svg')
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        print(f'  [{i+1}/{len(iso_codes)}] {code} — already exists, skip')
        continue
    url = BASE_URL.format(code=code)
    try:
        urllib.request.urlretrieve(url, dest)
        size = os.path.getsize(dest)
        print(f'  [{i+1}/{len(iso_codes)}] {code} — {size} bytes')
        time.sleep(0.05)  # gentle rate limit
    except Exception as e:
        print(f'  [{i+1}/{len(iso_codes)}] {code} — FAILED: {e}')
        failed.append(code)

print(f'\nDone. {len(iso_codes) - len(failed)} downloaded, {len(failed)} failed.')
if failed:
    print(f'Failed codes: {failed}')
