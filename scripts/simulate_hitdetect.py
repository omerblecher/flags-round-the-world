"""
Simulates the Dart hitTest() logic in Python to identify which polygon
failures cause WRONG country assignments in the game (not just "outside polygon").
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
    # Check screen area threshold (48x48dp)
    screen_area = rect_w * rect_h * scale * scale
    if screen_area < 2304.0:
        expansion_radius = math.sqrt(2304.0 / math.pi) / scale
        cx, cy = country['centroid']['x'], country['centroid']['y']
        return math.sqrt((px-cx)**2 + (py-cy)**2) <= expansion_radius
    diagonal = math.sqrt(rect_w**2 + rect_h**2)
    if diagonal < 1e-6:
        return False
    # Degenerate country check (4-vertex rectangle)
    is_deg = len(country['paths']) == 1 and country['paths'][0].count('L') == 3 and country['paths'][0].strip().endswith('Z')
    effective_min = max(min_scene_diag, diagonal * 2.0) if is_deg else min_scene_diag
    if diagonal >= effective_min:
        actual_rect = (rect_x, rect_y, rect_x + rect_w, rect_y + rect_h)
    else:
        scale_f = effective_min / diagonal
        cx, cy = country['centroid']['x'], country['centroid']['y']
        hw, hh = rect_w * scale_f / 2, rect_h * scale_f / 2
        actual_rect = (cx - hw, cy - hh, cx + hw, cy + hh)
    return actual_rect[0] <= px <= actual_rect[2] and actual_rect[1] <= py <= actual_rect[3]

def tiebreak_dist_sq(country, px, py):
    # Exact path hit: use min(poly_bbox_center, centroid)
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
    # Bbox-only: nearest vertex
    return nearest_vertex_dist_sq(country, px, py)

def hit_test(px, py):
    # Phase 1&2: exact path OR expanded bbox
    candidates = []
    for c in countries:
        in_path = any(point_in_polygon(px, py, parse_path(p)) for p in c['paths'])
        in_bbox = bbox_contains(c, px, py)
        if in_path or in_bbox:
            candidates.append(c)

    # Phase 3: fallback if nothing hit
    pool = candidates if candidates else [
        c for c in countries if bbox_contains(c, px, py)
    ]

    if not pool:
        return None
    if len(pool) == 1:
        return pool[0]['iso']

    pool.sort(key=lambda c: tiebreak_dist_sq(c, px, py))
    return pool[0]['iso']

# Test the 28 failures
failures = [
    ('ae', 'Abu Dhabi', 54.37, 24.47),
    ('ae', 'Dubai', 55.30, 25.26),
    ('cy', 'Nicosia', 33.37, 35.17),
    ('dj', 'Djibouti', 43.15, 11.59),
    ('dk', 'Copenhagen', 12.57, 55.68),
    ('fi', 'Helsinki', 24.94, 60.17),
    ('ga', 'Libreville', 9.45, 0.39),
    ('gh', 'Accra', -0.19, 5.56),
    ('gm', 'Banjul', -16.58, 13.45),
    ('gq', 'Malabo', 8.78, 3.75),
    ('hr', 'Dubrovnik', 18.09, 42.65),
    ('id', 'Surabaya', 112.73, -7.25),
    ('il', 'Jerusalem', 35.22, 31.78),
    ('is', 'Reykjavik', -22.00, 64.13),
    ('kr', 'Busan', 129.04, 35.10),
    ('kw', 'Kuwait City', 47.98, 29.37),
    ('lb', 'Beirut', 35.50, 33.89),
    ('lr', 'Monrovia', -10.80, 6.30),
    ('ly', 'Tripoli', 13.19, 32.90),
    ('ng', 'Lagos', 3.38, 6.45),
    ('nz', 'Auckland', 174.76, -36.85),
    ('pt', 'Lisbon', -9.14, 38.72),
    ('sl', 'Freetown', -13.23, 8.49),
    ('so', 'Mogadishu', 45.34, 2.05),
    ('tr', 'Istanbul', 28.96, 41.01),
    ('tz', 'Dar es Salaam', 39.28, -6.79),
    ('uy', 'Montevideo', -56.19, -34.91),
    ('za', 'Durban', 31.02, -29.86),
]

print(f'{"ISO":<5} {"City":<25} {"Expected":<8} {"Got":<8} {"Status"}')
print('-' * 70)
wrong = []
for iso, city, lon, lat in failures:
    px, py = scene(lon, lat)
    got = hit_test(px, py)
    ok = got == iso
    status = 'OK (bbox)' if ok else f'WRONG -> {(got or "none").upper()}'
    print(f'{iso.upper():<5} {city:<25} {iso.upper():<8} {(got or "none").upper():<8} {status}')
    if not ok:
        wrong.append((iso, city, got))

print(f'\n{len(wrong)} give wrong country in game, {len(failures)-len(wrong)} caught by bbox fallback.')
if wrong:
    print('NEED FIX:')
    for iso, city, got in wrong:
        print(f'  {iso.upper()} {city} -> got {(got or "none").upper()}')
