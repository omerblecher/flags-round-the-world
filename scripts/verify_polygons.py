import json, re, math

with open('assets/map/world_map_paths.json') as f:
    data = json.load(f)

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

# Capital cities + a few extra cities per tricky country
test_points = {
    'af': [('Kabul', 69.18, 34.52)],
    'al': [('Tirana', 19.82, 41.33)],
    'dz': [('Algiers', 3.06, 36.74)],
    'ao': [('Luanda', 13.23, -8.84)],
    'ar': [('Buenos Aires', -58.43, -34.60), ('Mendoza', -68.83, -32.89), ('Ushuaia', -68.30, -54.80)],
    'am': [('Yerevan', 44.50, 40.18)],
    'au': [('Canberra', 149.13, -35.28), ('Sydney', 151.21, -33.87), ('Perth', 115.86, -31.95)],
    'at': [('Vienna', 16.37, 48.21)],
    'az': [('Baku', 49.87, 40.41)],
    'bd': [('Dhaka', 90.41, 23.72)],
    'be': [('Brussels', 4.35, 50.85)],
    'bj': [('Porto-Novo', 2.62, 6.37)],
    'bo': [('Sucre', -65.26, -19.04)],
    'ba': [('Sarajevo', 18.42, 43.85)],
    'bw': [('Gaborone', 25.91, -24.65)],
    'br': [('Brasilia', -47.93, -15.78), ('Sao Paulo', -46.63, -23.55), ('Manaus', -60.02, -3.10)],
    'bg': [('Sofia', 23.32, 42.70)],
    'bf': [('Ouagadougou', -1.52, 12.37)],
    'bi': [('Gitega', 29.92, -3.43)],
    'kh': [('Phnom Penh', 104.92, 11.57)],
    'cm': [('Yaounde', 11.52, 3.87)],
    'ca': [('Ottawa', -75.70, 45.42), ('Vancouver', -123.12, 49.25), ('Toronto', -79.38, 43.65)],
    'cf': [('Bangui', 18.56, 4.36)],
    'td': [("N'Djamena", 15.03, 12.11)],
    'cl': [('Santiago', -70.67, -33.45), ('Punta Arenas', -70.92, -53.16)],
    'cn': [('Beijing', 116.40, 39.91), ('Shanghai', 121.47, 31.23), ('Urumqi', 87.60, 43.80)],
    'co': [('Bogota', -74.08, 4.71)],
    'cd': [('Kinshasa', 15.27, -4.32), ('Lubumbashi', 27.47, -11.67)],
    'cg': [('Brazzaville', 15.28, -4.27)],
    'cr': [('San Jose', -84.09, 9.93)],
    'ci': [('Yamoussoukro', -5.28, 6.82)],
    'hr': [('Zagreb', 15.98, 45.81), ('Dubrovnik', 18.09, 42.65)],
    'cu': [('Havana', -82.36, 23.14)],
    'cy': [('Nicosia', 33.37, 35.17)],
    'cz': [('Prague', 14.47, 50.08), ('Brno', 16.61, 49.20)],
    'dk': [('Copenhagen', 12.57, 55.68)],
    'dj': [('Djibouti', 43.15, 11.59)],
    'do': [('Santo Domingo', -69.90, 18.48)],
    'ec': [('Quito', -78.52, -0.23), ('Guayaquil', -79.90, -2.19)],
    'eg': [('Cairo', 31.25, 30.06), ('Alexandria', 29.92, 31.20)],
    'sv': [('San Salvador', -89.19, 13.69)],
    'gq': [('Malabo', 8.78, 3.75)],
    'er': [('Asmara', 38.93, 15.34)],
    'ee': [('Tallinn', 24.75, 59.44)],
    'et': [('Addis Ababa', 38.70, 9.02)],
    'fi': [('Helsinki', 24.94, 60.17), ('Oulu', 25.47, 65.01)],
    'fr': [('Paris', 2.35, 48.86), ('Marseille', 5.37, 43.30), ('Lyon', 4.84, 45.75)],
    'ga': [('Libreville', 9.45, 0.39)],
    'gm': [('Banjul', -16.58, 13.45)],
    'ge': [('Tbilisi', 44.83, 41.69)],
    'de': [('Berlin', 13.41, 52.52), ('Munich', 11.58, 48.14), ('Hamburg', 9.99, 53.55)],
    'gh': [('Accra', -0.19, 5.56)],
    'gr': [('Athens', 23.73, 37.98), ('Thessaloniki', 22.94, 40.64)],
    'gt': [('Guatemala City', -90.52, 14.64)],
    'gn': [('Conakry', -13.68, 9.54)],
    'gy': [('Georgetown', -58.16, 6.80)],
    'ht': [('Port-au-Prince', -72.34, 18.54)],
    'hn': [('Tegucigalpa', -87.22, 14.09)],
    'hu': [('Budapest', 19.04, 47.50)],
    'is': [('Reykjavik', -22.00, 64.13)],
    'in': [('New Delhi', 77.21, 28.63), ('Mumbai', 72.88, 19.07), ('Chennai', 80.28, 13.09)],
    'id': [('Jakarta', 106.85, -6.21), ('Surabaya', 112.73, -7.25)],
    'ir': [('Tehran', 51.39, 35.69), ('Isfahan', 51.68, 32.66)],
    'iq': [('Baghdad', 44.36, 33.34)],
    'ie': [('Dublin', -6.27, 53.33)],
    'il': [('Jerusalem', 35.22, 31.78), ('Tel Aviv', 34.78, 32.07)],
    'it': [('Rome', 12.49, 41.90), ('Naples', 14.27, 40.84), ('Reggio Calabria', 15.65, 38.11), ('Palermo', 13.36, 38.12)],
    'jp': [('Tokyo', 139.69, 35.69), ('Osaka', 135.50, 34.69), ('Sapporo', 141.35, 43.06)],
    'jo': [('Amman', 35.93, 31.95)],
    'kz': [('Nur-Sultan', 71.45, 51.18), ('Almaty', 76.95, 43.26)],
    'ke': [('Nairobi', 36.82, -1.29), ('Mombasa', 39.67, -4.05)],
    'kp': [('Pyongyang', 125.73, 39.02)],
    'kr': [('Seoul', 126.98, 37.57), ('Busan', 129.04, 35.10)],
    'kw': [('Kuwait City', 47.98, 29.37)],
    'kg': [('Bishkek', 74.58, 42.87)],
    'la': [('Vientiane', 102.62, 17.97)],
    'lv': [('Riga', 24.11, 56.95)],
    'lb': [('Beirut', 35.50, 33.89)],
    'ls': [('Maseru', 27.47, -29.32)],
    'lr': [('Monrovia', -10.80, 6.30)],
    'ly': [('Tripoli', 13.19, 32.90)],
    'lt': [('Vilnius', 25.28, 54.69)],
    'lu': [('Luxembourg', 6.13, 49.61)],
    'mg': [('Antananarivo', 47.52, -18.91)],
    'mw': [('Lilongwe', 33.78, -13.97)],
    'my': [('Kuala Lumpur', 101.69, 3.14)],
    'ml': [('Bamako', -8.00, 12.65)],
    'mr': [('Nouakchott', -15.97, 18.08)],
    'mx': [('Mexico City', -99.13, 19.43), ('Guadalajara', -103.34, 20.67)],
    'md': [('Chisinau', 28.86, 47.01)],
    'mn': [('Ulaanbaatar', 106.90, 47.91)],
    'me': [('Podgorica', 19.27, 42.44)],
    'ma': [('Rabat', -6.84, 33.99), ('Casablanca', -7.59, 33.59)],
    'mz': [('Maputo', 32.59, -25.97)],
    'mm': [('Naypyidaw', 96.13, 19.74), ('Yangon', 96.16, 16.87)],
    'na': [('Windhoek', 17.08, -22.56)],
    'np': [('Kathmandu', 85.32, 27.72)],
    'nl': [('Amsterdam', 4.90, 52.37)],
    'nz': [('Wellington', 174.78, -41.29), ('Auckland', 174.76, -36.85)],
    'ni': [('Managua', -86.29, 12.13)],
    'ne': [('Niamey', 2.11, 13.51)],
    'ng': [('Abuja', 7.49, 9.06), ('Lagos', 3.38, 6.45)],
    'mk': [('Skopje', 21.43, 42.00)],
    'no': [('Oslo', 10.75, 59.91), ('Bergen', 5.33, 60.39)],
    'om': [('Muscat', 58.59, 23.61)],
    'pk': [('Islamabad', 73.04, 33.72), ('Karachi', 67.01, 24.86)],
    'pa': [('Panama City', -79.52, 8.99)],
    'py': [('Asuncion', -57.65, -25.29)],
    'pe': [('Lima', -77.04, -12.05), ('Cusco', -71.98, -13.52)],
    'ph': [('Manila', 120.98, 14.60)],
    'pl': [('Warsaw', 21.02, 52.23), ('Krakow', 19.94, 50.06), ('Gdansk', 18.65, 54.35), ('Wroclaw', 17.03, 51.11)],
    'pt': [('Lisbon', -9.14, 38.72), ('Porto', -8.61, 41.15)],
    'ro': [('Bucharest', 26.10, 44.44), ('Cluj', 23.59, 46.77)],
    'ru': [('Moscow', 37.62, 55.75), ('Vladivostok', 131.91, 43.12), ('Novosibirsk', 82.93, 55.03)],
    'rw': [('Kigali', 30.06, -1.95)],
    'sa': [('Riyadh', 46.72, 24.69), ('Jeddah', 39.17, 21.49)],
    'sn': [('Dakar', -17.45, 14.72)],
    'rs': [('Belgrade', 20.46, 44.80)],
    'sl': [('Freetown', -13.23, 8.49)],
    'sk': [('Bratislava', 17.11, 48.15)],
    'si': [('Ljubljana', 14.51, 46.05)],
    'so': [('Mogadishu', 45.34, 2.05)],
    'za': [('Pretoria', 28.19, -25.74), ('Cape Town', 18.42, -33.93), ('Durban', 31.02, -29.86)],
    'ss': [('Juba', 31.58, 4.86)],
    'es': [('Madrid', -3.70, 40.42), ('Barcelona', 2.15, 41.39), ('Seville', -5.99, 37.39)],
    'lk': [('Colombo', 79.86, 6.93)],
    'sd': [('Khartoum', 32.53, 15.55)],
    'sr': [('Paramaribo', -55.17, 5.85)],
    'se': [('Stockholm', 18.07, 59.33), ('Gothenburg', 11.97, 57.71)],
    'ch': [('Bern', 7.45, 46.95), ('Zurich', 8.54, 47.38), ('Geneva', 6.14, 46.20)],
    'sy': [('Damascus', 36.29, 33.51)],
    'tj': [('Dushanbe', 68.77, 38.56)],
    'tz': [('Dodoma', 35.74, -6.18), ('Dar es Salaam', 39.28, -6.79)],
    'th': [('Bangkok', 100.50, 13.75), ('Chiang Mai', 98.98, 18.78), ('Hat Yai', 100.47, 7.01)],
    'tl': [('Dili', 125.57, -8.56)],
    'tg': [('Lome', 1.22, 6.13)],
    'tn': [('Tunis', 10.18, 36.82)],
    'tr': [('Ankara', 32.86, 39.93), ('Istanbul', 28.96, 41.01)],
    'tm': [('Ashgabat', 58.38, 37.96)],
    'ug': [('Kampala', 32.58, 0.32)],
    'ua': [('Kyiv', 30.52, 50.45), ('Kharkiv', 36.23, 49.99), ('Lviv', 24.03, 49.84)],
    'ae': [('Abu Dhabi', 54.37, 24.47), ('Dubai', 55.30, 25.26)],
    'gb': [('London', -0.13, 51.51), ('Edinburgh', -3.19, 55.95), ('Cardiff', -3.18, 51.48)],
    'us': [('Washington DC', -77.04, 38.91), ('Los Angeles', -118.24, 34.05), ('Chicago', -87.63, 41.88), ('Houston', -95.37, 29.76)],
    'uy': [('Montevideo', -56.19, -34.91)],
    'uz': [('Tashkent', 69.24, 41.30), ('Samarkand', 66.96, 39.66)],
    've': [('Caracas', -66.92, 10.48)],
    'vn': [('Hanoi', 105.83, 21.02), ('Da Nang', 108.22, 16.07), ('Ho Chi Minh City', 106.66, 10.82)],
    'ye': [('Sanaa', 44.21, 15.35)],
    'zm': [('Lusaka', 28.28, -15.42)],
    'zw': [('Harare', 31.05, -17.83)],
    'xk': [('Pristina', 21.17, 42.67)],
    'tw': [('Taipei', 121.54, 25.05)],
}

country_map = {c['iso']: c for c in data['countries']}

fails = []
passes = 0
for iso, points in sorted(test_points.items()):
    if iso not in country_map:
        fails.append((iso, '?', '?', '?', 'MISSING from JSON'))
        continue
    country = country_map[iso]
    for city, lon, lat in points:
        cx, cy = scene(lon, lat)
        inside = any(point_in_polygon(cx, cy, parse_path(p)) for p in country['paths'])
        verts = sum(len(parse_path(p)) for p in country['paths'])
        if inside:
            passes += 1
        else:
            fails.append((iso, city, lon, lat, f'OUTSIDE polygon (verts={verts})'))

total = passes + len(fails)
print(f'Results: {passes}/{total} passed, {len(fails)} failed\n')
if fails:
    for iso, city, lon, lat, reason in fails:
        print(f'  {iso.upper():4s} {city:<28s} {reason}')
else:
    print('All test points are inside their polygons.')
