#!/usr/bin/env python3
"""Convert Natural Earth GeoJSON into Colorvia's compact normalized resources."""

import json
import math
import sys
from pathlib import Path


CONTINENTS = {
    "Asia": "asia",
    "Europe": "europe",
    "Africa": "africa",
    "North America": "northAmerica",
    "South America": "southAmerica",
    "Oceania": "oceania",
}

PROGRESS_COUNTRIES = set(
    """
    DZ AO BJ BW BF BI CV CM CF TD KM CD CG CI DJ EG GQ ER SZ ET GA GM GH GN GW KE LS LR LY MG MW ML MR MU MA MZ NA NE NG RW ST SN SC SL SO ZA SS SD TZ TG TN UG ZM ZW
    AF AM AZ BH BD BT BN KH CN CY GE IN ID IR IQ IL JP JO KZ KW KG LA LB MY MV MN MM NP KP OM PK PS PH QA SA SG KR LK SY TJ TH TL TR TM AE UZ VN YE
    AL AD AT BY BE BA BG HR CZ DK EE FI FR DE GR VA HU IS IE IT LV LI LT LU MT MD MC ME NL MK NO PL PT RO RU SM RS SK SI ES SE CH UA GB
    AG BS BB BZ CA CR CU DM DO SV GD GT HT HN JM MX NI PA KN LC VC TT US
    AR BO BR CL CO EC GY PY PE SR UY VE
    AU FJ KI MH FM NR NZ PW PG WS SB TO TV VU
    """.split()
)

EXTRA_COUNTRIES = [
    ("AD", "AND", "Andorra", "europe"), ("AG", "ATG", "Antigua and Barbuda", "northAmerica"),
    ("BB", "BRB", "Barbados", "northAmerica"), ("BH", "BHR", "Bahrain", "asia"),
    ("CV", "CPV", "Cabo Verde", "africa"), ("DM", "DMA", "Dominica", "northAmerica"),
    ("FM", "FSM", "Micronesia", "oceania"), ("GD", "GRD", "Grenada", "northAmerica"),
    ("KI", "KIR", "Kiribati", "oceania"), ("KM", "COM", "Comoros", "africa"),
    ("KN", "KNA", "Saint Kitts and Nevis", "northAmerica"), ("LC", "LCA", "Saint Lucia", "northAmerica"),
    ("LI", "LIE", "Liechtenstein", "europe"), ("MC", "MCO", "Monaco", "europe"),
    ("MH", "MHL", "Marshall Islands", "oceania"), ("MT", "MLT", "Malta", "europe"),
    ("MU", "MUS", "Mauritius", "africa"), ("MV", "MDV", "Maldives", "asia"),
    ("NR", "NRU", "Nauru", "oceania"), ("PW", "PLW", "Palau", "oceania"),
    ("SC", "SYC", "Seychelles", "africa"), ("SG", "SGP", "Singapore", "asia"),
    ("SM", "SMR", "San Marino", "europe"), ("ST", "STP", "São Tomé and Príncipe", "africa"),
    ("TO", "TON", "Tonga", "oceania"), ("TV", "TUV", "Tuvalu", "oceania"),
    ("VA", "VAT", "Vatican City", "europe"), ("VC", "VCT", "Saint Vincent and the Grenadines", "northAmerica"),
    ("WS", "WSM", "Samoa", "oceania"),
]


def point_line_distance(point, start, end):
    if start == end:
        return math.dist(point, start)
    dx, dy = end[0] - start[0], end[1] - start[1]
    t = max(0, min(1, ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / (dx * dx + dy * dy)))
    return math.dist(point, (start[0] + t * dx, start[1] + t * dy))


def simplify(points, epsilon=0.18):
    if len(points) < 4:
        return points
    maximum, index = 0, 0
    for i in range(1, len(points) - 1):
        distance = point_line_distance(points[i], points[0], points[-1])
        if distance > maximum:
            maximum, index = distance, i
    if maximum > epsilon:
        left = simplify(points[: index + 1], epsilon)
        right = simplify(points[index:], epsilon)
        return left[:-1] + right
    return [points[0], points[-1]]


def rings(geometry):
    if geometry["type"] == "Polygon":
        return [geometry["coordinates"][0]]
    if geometry["type"] == "MultiPolygon":
        return [polygon[0] for polygon in geometry["coordinates"]]
    return []


def normalize(ring):
    output = []
    for lon, lat in simplify(ring):
        x = round((lon + 180) / 360, 5)
        y = round((90 - max(-60, min(90, lat))) / 150, 5)
        output.append({"x": x, "y": y})
    return output


def main():
    source, output_dir = Path(sys.argv[1]), Path(sys.argv[2])
    data = json.loads(source.read_text())
    map_countries, countries = [], []
    used = set()
    for feature in data["features"]:
        p = feature["properties"]
        code = p.get("ISO_A2")
        code = {"-99": {"FRA": "FR", "NOR": "NO"}.get(p.get("ADM0_A3")), "CN-TW": "TW"}.get(code, code)
        continent = CONTINENTS.get(p.get("CONTINENT"))
        if not code or code == "-99" or not continent or code in used:
            continue
        polygons = [normalize(ring) for ring in rings(feature["geometry"]) if len(ring) >= 4]
        polygons = [ring for ring in polygons if len(ring) >= 3]
        if not polygons:
            continue
        used.add(code)
        map_countries.append({"code": code, "polygons": polygons})
        countries.append({
            "id": code,
            "alpha2Code": code,
            "alpha3Code": p.get("ISO_A3", ""),
            "englishName": p.get("NAME_EN") or p.get("NAME") or code,
            "continent": continent,
            "isProgressEligible": code in PROGRESS_COUNTRIES,
            "isTerritory": code not in PROGRESS_COUNTRIES,
        })
    for code, alpha3, name, continent in EXTRA_COUNTRIES:
        if code not in used:
            countries.append({
                "id": code,
                "alpha2Code": code,
                "alpha3Code": alpha3,
                "englishName": name,
                "continent": continent,
                "isProgressEligible": True,
                "isTerritory": False,
            })
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "world-map.json").write_text(json.dumps(map_countries, separators=(",", ":")))
    (output_dir / "countries.json").write_text(json.dumps(sorted(countries, key=lambda item: item["englishName"]), ensure_ascii=False, indent=2))
    print(f"Wrote {len(countries)} countries")


if __name__ == "__main__":
    main()
