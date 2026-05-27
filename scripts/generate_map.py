import geopandas as gpd
import json
import argparse
from shapely.geometry import MultiPolygon, Polygon
from shapely.ops import unary_union

VIEWBOX_WIDTH = 2000.0
VIEWBOX_HEIGHT = 1000.0

# The 196 target sovereign states: UN-193 + Holy See + Taiwan + Kosovo
TARGET_196 = {
    'af','al','dz','ad','ao','ag','ar','am','au','at','az','bs','bh','bd',
    'bb','by','be','bz','bj','bt','bo','ba','bw','br','bn','bg','bf','bi',
    'cv','kh','cm','ca','cf','td','cl','cn','co','km','cd','cg','cr','ci',
    'hr','cu','cy','cz','dk','dj','dm','do','ec','eg','sv','gq','er','ee',
    'sz','et','fj','fi','fr','ga','gm','ge','de','gh','gr','gd','gt','gn',
    'gw','gy','ht','hn','hu','is','in','id','ir','iq','ie','il','it','jm',
    'jp','jo','kz','ke','ki','kp','kr','kw','kg','la','lv','lb','ls','lr',
    'ly','li','lt','lu','mg','mw','my','mv','ml','mt','mh','mr','mu','mx',
    'fm','md','mc','mn','me','ma','mz','mm','na','nr','np','nl','nz','ni',
    'ne','ng','mk','no','om','pk','pw','pa','pg','py','pe','ph','pl','pt',
    'qa','ro','ru','rw','kn','lc','vc','ws','sm','st','sa','sn','rs','sc',
    'sl','sg','sk','si','sb','so','za','ss','es','lk','sd','sr','se','ch',
    'sy','tj','tz','th','tl','tg','to','tt','tn','tr','tm','tv','ug','ua',
    'ae','gb','us','uy','uz','vu','ve','vn','ye','zm','zw',
    'va','tw','xk',  # Holy See, Taiwan, Kosovo
}

# Approximate centroids (lon, lat) for micro-states not in Natural Earth 110m
SYNTHETIC_CENTROIDS = {
    'ad': (1.5,   42.5),   # Andorra
    'ag': (-61.8, 17.1),   # Antigua and Barbuda
    'bb': (-59.5, 13.2),   # Barbados
    'bh': (50.6,  26.0),   # Bahrain
    'cv': (-24.0, 16.0),   # Cabo Verde
    'dm': (-61.4, 15.4),   # Dominica
    'fm': (158.3,  6.9),   # Micronesia
    'gd': (-61.7, 12.1),   # Grenada
    'ki': (173.0,  1.3),   # Kiribati (central island group)
    'km': (43.4, -11.7),   # Comoros
    'kn': (-62.8, 17.3),   # Saint Kitts and Nevis
    'lc': (-60.9, 13.9),   # Saint Lucia
    'li': (9.5,  47.2),   # Liechtenstein
    'mc': (7.4,  43.7),   # Monaco
    'mh': (171.2,  7.1),   # Marshall Islands
    'mt': (14.5, 35.9),   # Malta
    'mu': (57.6, -20.3),  # Mauritius
    'mv': (73.2,   3.2),   # Maldives
    'nr': (166.9, -0.5),  # Nauru
    'pw': (134.6,  7.5),   # Palau
    'sc': (55.5,  -4.7),  # Seychelles
    'sg': (103.8,  1.3),   # Singapore
    'sm': (12.5, 43.9),   # San Marino
    'st': (6.6,   0.2),   # São Tomé and Príncipe
    'to': (-175.2, -21.2), # Tonga
    'tv': (179.2,  -8.0),  # Tuvalu
    'va': (12.5, 41.9),   # Vatican City
    'vc': (-61.2, 12.9),   # Saint Vincent and the Grenadines
    'ws': (-172.1, -13.8), # Samoa
}

# Size of synthetic bounding box in degrees
SYNTHETIC_SIZE_DEG = 1.5


def lon_to_x(lon):
    return round((lon + 180.0) / 360.0 * VIEWBOX_WIDTH, 2)


def lat_to_y(lat):
    return round((90.0 - lat) / 180.0 * VIEWBOX_HEIGHT, 2)


def get_iso_code(row):
    # Try ISO_A2 first, then ISO_A2_EH as fallback
    for field in ('ISO_A2', 'ISO_A2_EH'):
        iso = str(row.get(field, '-99')).strip()
        if iso and iso != '-99' and len(iso) == 2:
            iso = iso.lower()
            if iso in TARGET_196:
                return iso
    # Name-based fallback for Kosovo/Taiwan
    name = str(row.get('NAME', '')) + ' ' + str(row.get('ADMIN', ''))
    if 'Kosovo' in name:
        return 'xk'
    if 'Taiwan' in name:
        return 'tw'
    return None


def polygon_to_path(polygon):
    coords = list(polygon.exterior.coords)[:-1]
    if len(coords) < 3:
        return None
    parts = [f"M{lon_to_x(coords[0][0])},{lat_to_y(coords[0][1])}"]
    for lon, lat in coords[1:]:
        parts.append(f"L{lon_to_x(lon)},{lat_to_y(lat)}")
    parts.append("Z")
    return " ".join(parts)


def synthetic_entry(iso, lon, lat, size_deg=SYNTHETIC_SIZE_DEG):
    half = size_deg / 2.0
    corners = [
        (lon - half, lat + half),
        (lon + half, lat + half),
        (lon + half, lat - half),
        (lon - half, lat - half),
    ]
    path_parts = [f"M{lon_to_x(corners[0][0])},{lat_to_y(corners[0][1])}"]
    for c_lon, c_lat in corners[1:]:
        path_parts.append(f"L{lon_to_x(c_lon)},{lat_to_y(c_lat)}")
    path_parts.append("Z")
    path = " ".join(path_parts)

    cx = lon_to_x(lon)
    cy = lat_to_y(lat)
    xs = [lon_to_x(c[0]) for c in corners]
    ys = [lat_to_y(c[1]) for c in corners]
    return {
        "iso": iso,
        "paths": [path],
        "boundingBox": {
            "x": min(xs), "y": min(ys),
            "w": round(max(xs) - min(xs), 2),
            "h": round(max(ys) - min(ys), 2),
        },
        "centroid": {"x": cx, "y": cy},
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', default=None)
    args = parser.parse_args()

    url = args.input or 'https://naciscdn.org/naturalearth/110m/cultural/ne_110m_admin_0_countries.zip'
    print(f"Loading from {url}...")
    gdf = gpd.read_file(url)
    gdf = gdf.to_crs('EPSG:4326')

    # Group rows by ISO code (only target countries)
    country_groups = {}
    for _, row in gdf.iterrows():
        iso = get_iso_code(row)
        if iso is None:
            continue
        country_groups.setdefault(iso, []).append(row)

    countries_map = {}

    # Process countries found in Natural Earth
    for iso, rows in country_groups.items():
        all_paths = []
        all_xs = []
        all_ys = []
        geometries = []

        for row in rows:
            geom = row.geometry
            if geom is None:
                continue
            geometries.append(geom)
            polys = list(geom.geoms) if isinstance(geom, MultiPolygon) else [geom]
            for poly in polys:
                if not isinstance(poly, Polygon):
                    continue
                path = polygon_to_path(poly)
                if path:
                    all_paths.append(path)
                for lon, lat in list(poly.exterior.coords):
                    all_xs.append(lon_to_x(lon))
                    all_ys.append(lat_to_y(lat))

        if not all_paths or not all_xs:
            continue

        try:
            merged = unary_union(geometries)
            cx = lon_to_x(merged.centroid.x)
            cy = lat_to_y(merged.centroid.y)
        except Exception:
            cx = round(sum(all_xs) / len(all_xs), 2)
            cy = round(sum(all_ys) / len(all_ys), 2)

        min_x, max_x = min(all_xs), max(all_xs)
        min_y, max_y = min(all_ys), max(all_ys)

        countries_map[iso] = {
            "iso": iso,
            "paths": all_paths,
            "boundingBox": {
                "x": min_x, "y": min_y,
                "w": round(max_x - min_x, 2),
                "h": round(max_y - min_y, 2),
            },
            "centroid": {"x": cx, "y": cy},
        }

    # Add synthetic geometry for micro-states not in Natural Earth 110m
    for iso, (lon, lat) in SYNTHETIC_CENTROIDS.items():
        if iso not in countries_map:
            countries_map[iso] = synthetic_entry(iso, lon, lat)
            print(f"  Synthetic geometry added for {iso}")

    # Check for any target countries still missing
    missing = TARGET_196 - set(countries_map.keys())
    if missing:
        print(f"WARNING: Still missing {len(missing)} countries: {sorted(missing)}")

    countries = sorted(countries_map.values(), key=lambda c: c['iso'])

    output = {
        "version": 1,
        "viewBox": {"width": 2000, "height": 1000},
        "countries": countries,
    }

    out_path = 'assets/map/world_map_paths.json'
    with open(out_path, 'w') as f:
        json.dump(output, f, separators=(',', ':'))
    print(f"Generated {len(countries)} countries")


if __name__ == '__main__':
    main()
