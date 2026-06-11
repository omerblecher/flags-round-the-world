"""
Simulates the Dart hitTest() logic in Python to identify which polygon
failures cause WRONG country assignments in the game (not just "outside polygon").

IMPORTANT: hit_test() must mirror hit_detection.dart exactly.
The key invariant: exact-path hits always beat bbox-only hits.
Degenerate (synthetic 4-vertex) countries are promoted to the exact-path pool
so micro-states (Singapore, Monaco) beat the surrounding country's real polygon.
"""
import json, re, math

with open('assets/map/world_map_paths.json') as f:
    data = json.load(f)

countries = data['countries']

def parse_path(path):
    coords = re.findall(r'[ML]([\d.]+),([\d.]+)', path)
    return [(float(x), float(y)) for x, y in coords]

def point_in_polygon(px, py, polygon):
    n = len(polygon)
    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = polygon[i]
        xj, yj = polygon[j]
        if ((yi > py) != (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi):
            inside = not inside
        j = i
    return inside

def scene(lon, lat):
    return (lon + 180) / 360 * 2000, (90 - lat) / 180 * 1000

def is_degenerate(country):
    paths = country['paths']
    if len(paths) != 1:
        return False
    s = paths[0]
    return s.count('L') == 3 and s.rstrip().endswith('Z')

def nearest_vertex_dist_sq(country, px, py):
    min_d = float('inf')
    for p in country['paths']:
        for x, y in parse_path(p):
            d = (x - px)**2 + (y - py)**2
            if d < min_d:
                min_d = d
    return min_d

def bbox_contains(country, px, py, scale=1.0, min_screen_diag=40.0):
    bb = country['boundingBox']
    rect_x, rect_y, rect_w, rect_h = bb['x'], bb['y'], bb['w'], bb['h']
    min_scene_diag = min_screen_diag / scale
    screen_area = rect_w * rect_h * scale * scale
    # Degenerate (synthetic) countries skip the 48dp circular expansion.
    # Their 1.5° synthetic box already gets a 2x-diagonal rect expansion below,
    # which covers ~14 scene units from the centroid. The circular expansion
    # (~27 units) would reach far into neighbouring continental territory —
    # e.g. BH (Bahrain) swallowing Abu Dhabi, MT (Malta) swallowing Tripoli.
    if screen_area < 2304.0 and not is_degenerate(country):
        expansion_radius = math.sqrt(2304.0 / math.pi) / scale
        cx, cy = country['centroid']['x'], country['centroid']['y']
        return math.sqrt((px-cx)**2 + (py-cy)**2) <= expansion_radius
    diagonal = math.sqrt(rect_w**2 + rect_h**2)
    if diagonal < 1e-6:
        return False
    effective_min = max(min_scene_diag, diagonal * 2.0) if is_degenerate(country) else min_scene_diag
    if diagonal >= effective_min:
        actual_rect = (rect_x, rect_y, rect_x + rect_w, rect_y + rect_h)
    else:
        scale_f = effective_min / diagonal
        cx, cy = country['centroid']['x'], country['centroid']['y']
        hw, hh = rect_w * scale_f / 2, rect_h * scale_f / 2
        actual_rect = (cx - hw, cy - hh, cx + hw, cy + hh)
    return actual_rect[0] <= px <= actual_rect[2] and actual_rect[1] <= py <= actual_rect[3]

def tiebreak_dist_sq(country, px, py):
    for p in country['paths']:
        verts = parse_path(p)
        if point_in_polygon(px, py, verts):
            xs = [v[0] for v in verts]
            ys = [v[1] for v in verts]
            pcx, pcy = (min(xs)+max(xs))/2, (min(ys)+max(ys))/2
            poly_d = (pcx-px)**2 + (pcy-py)**2
            cx, cy = country['centroid']['x'], country['centroid']['y']
            cent_d = (cx-px)**2 + (cy-py)**2
            return min(poly_d, cent_d)
    return nearest_vertex_dist_sq(country, px, py)

def hit_test(px, py):
    # Mirror hit_detection.dart: separate exact-path hits from bbox-only hits.
    # Exact-path pool always wins — prevents a neighbour's close polygon vertex
    # from beating the correct country whose polygon actually contains the drop.
    # Degenerate countries (synthetic 4-vertex rects for micro-states) are
    # promoted to exact-path pool so they can beat the surrounding country.
    exact_hits = []
    bbox_hits = []
    for c in countries:
        in_path = any(point_in_polygon(px, py, parse_path(p)) for p in c['paths'])
        if in_path:
            exact_hits.append(c)
        elif bbox_contains(c, px, py):
            if is_degenerate(c):
                exact_hits.append(c)
            else:
                bbox_hits.append(c)

    if exact_hits:
        pool = exact_hits
    elif bbox_hits:
        pool = bbox_hits
    else:
        # Ocean fallback: expanded bbox for all countries
        pool = [c for c in countries if bbox_contains(c, px, py)]

    if not pool:
        return None
    if len(pool) == 1:
        return pool[0]['iso']

    pool.sort(key=lambda c: tiebreak_dist_sq(c, px, py))
    return pool[0]['iso']

# ── 28 original UAT tests ──────────────────────────────────────────────────
uat_28 = [
    ('ae', 'Abu Dhabi',       54.37,  24.47),
    ('ae', 'Dubai',           55.30,  25.26),
    ('cy', 'Nicosia',         33.37,  35.17),
    ('dj', 'Djibouti',        43.15,  11.59),
    ('dk', 'Copenhagen',      12.57,  55.68),
    ('fi', 'Helsinki',        24.94,  60.17),
    ('ga', 'Libreville',       9.45,   0.39),
    ('gh', 'Accra',           -0.19,   5.56),
    ('gm', 'Banjul',         -16.58,  13.45),
    ('gq', 'Malabo',           8.78,   3.75),
    ('hr', 'Dubrovnik',       18.09,  42.65),
    ('id', 'Surabaya',       112.73,  -7.25),
    ('il', 'Jerusalem',       35.22,  31.78),
    ('is', 'Reykjavik',      -22.00,  64.13),
    ('kr', 'Busan',          129.04,  35.10),
    ('kw', 'Kuwait City',     47.98,  29.37),
    ('lb', 'Beirut',          35.50,  33.89),
    ('lr', 'Monrovia',       -10.80,   6.30),
    ('ly', 'Tripoli',         13.19,  32.90),
    ('ng', 'Lagos',            3.38,   6.45),
    ('nz', 'Auckland',       174.76, -36.85),
    ('pt', 'Lisbon',          -9.14,  38.72),
    ('sl', 'Freetown',       -13.23,   8.49),
    ('so', 'Mogadishu',       45.34,   2.05),
    ('tr', 'Istanbul',        28.96,  41.01),
    ('tz', 'Dar es Salaam',   39.28,  -6.79),
    ('uy', 'Montevideo',     -56.19, -34.91),
    ('za', 'Durban',          31.02, -29.86),
]

# ── 6 border-overlap tests (previously failing at 0.04° simplification) ───
border_6 = [
    ('kz', 'N Kazakhstan (Kostanay)',  63.63,  53.21),
    ('am', 'E Armenia (Vardenis)',     45.72,  40.18),
    ('la', 'N Laos (Phongsali)',      102.10,  21.65),
    ('la', 'S Laos (Paksong)',        106.24,  15.11),
    ('pt', 'N Portugal (Braganca)',   -6.76,   41.81),
    ('mn', 'S Mongolia (Dalanzadgad)',104.43,  43.57),
]

def run_suite(label, tests):
    print(f'\n{"-"*70}')
    print(f'{label}')
    print(f'{"-"*70}')
    print(f'{"ISO":<5} {"City":<30} {"Expected":<10} {"Got":<10} {"Status"}')
    print('-' * 70)
    wrong = []
    for iso, city, lon, lat in tests:
        px, py = scene(lon, lat)
        got = hit_test(px, py)
        ok = got == iso
        status = 'OK' if ok else f'WRONG -> {(got or "none").upper()}'
        print(f'{iso.upper():<5} {city:<30} {iso.upper():<10} {(got or "none").upper():<10} {status}')
        if not ok:
            wrong.append((iso, city, got))
    total = len(tests)
    print(f'\n{total - len(wrong)}/{total} passed.')
    if wrong:
        print('FAILURES:')
        for iso, city, got in wrong:
            print(f'  {iso.upper()} {city} -> got {(got or "none").upper()}')
    return wrong

w1 = run_suite('UAT-28 (original regression tests)', uat_28)
w2 = run_suite('BORDER-6 (simplification overlap tests)', border_6)

total_wrong = len(w1) + len(w2)
print(f'\n{"="*70}')
print(f'TOTAL: {34 - total_wrong}/34 passed  ({total_wrong} failed)')
