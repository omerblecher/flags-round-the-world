import json
import pycountry
from babel import Locale as BabelLocale

with open('assets/map/world_map_paths.json') as f:
    map_data = json.load(f)
isos = [c['iso'] for c in map_data['countries']]

EN_OVERRIDES = {
    'xk': 'Kosovo',
    'tw': 'Taiwan',
    'va': 'Vatican City',
    'ir': 'Iran',
    'kp': 'North Korea',
    'kr': 'South Korea',
    'md': 'Moldova',
    'cd': 'DR Congo',
    'cg': 'Republic of Congo',
    'tz': 'Tanzania',
    'vn': 'Vietnam',
    'la': 'Laos',
    'bo': 'Bolivia',
    'ci': "Côte d'Ivoire",
    'fm': 'Micronesia',
    'cv': 'Cabo Verde',
    'mk': 'North Macedonia',
    'sz': 'Eswatini',
    'tl': 'Timor-Leste',
    'ps': 'Palestine',
}


def get_en_name(iso):
    if iso in EN_OVERRIDES:
        return EN_OVERRIDES[iso]
    try:
        c = pycountry.countries.get(alpha_2=iso.upper())
        if c:
            name = c.name
            for suffix in [', Province of China', 'Plurinational State of ',
                           "Lao People's Democratic Republic",
                           'Democratic Republic of the Congo',
                           'Syrian Arab Republic',
                           'Bolivarian Republic of Venezuela']:
                if suffix in name:
                    if 'Lao' in suffix:
                        return 'Laos'
                    if 'Venezuela' in suffix:
                        return 'Venezuela'
                    if 'Syrian' in suffix:
                        return 'Syria'
                    name = name.replace(suffix, '').strip(', ')
            return name
    except Exception:
        pass
    print(f"WARNING: No English name for {iso}", flush=True)
    return f'Unknown ({iso})'


def get_es_name(iso):
    try:
        locale = BabelLocale.parse('es')
        name = locale.territories.get(iso.upper())
        if name:
            return name
    except Exception:
        pass
    return get_en_name(iso)


en_names = {iso: get_en_name(iso) for iso in isos}
es_names = {iso: get_es_name(iso) for iso in isos}

with open('assets/data/countries_en.json', 'w', encoding='utf-8') as f:
    json.dump(en_names, f, ensure_ascii=False, separators=(',', ':'))

with open('assets/data/countries_es.json', 'w', encoding='utf-8') as f:
    json.dump(es_names, f, ensure_ascii=False, separators=(',', ':'))

print(f"Generated {len(en_names)} English names, {len(es_names)} Spanish names")
