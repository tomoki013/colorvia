#!/usr/bin/env python3
"""Generate offline Japan place search and France department resources."""

import csv
import json
import math
import re
import sys
import unicodedata
from pathlib import Path


OVERSEAS_CODES = {
    "FR-GP": "FR-971",
    "FR-MQ": "FR-972",
    "FR-GF": "FR-973",
    "FR-RE": "FR-974",
    "FR-YT": "FR-976",
}

JAPAN_MANUAL_ALIASES = [
    ("博多", "JP-40", ["博多", "はかた", "hakata"], "commonName"),
    ("難波", "JP-27", ["難波", "なんば", "namba"], "commonName"),
    ("嵐山", "JP-26", ["嵐山", "あらしやま", "arashiyama"], "touristArea"),
    ("有馬温泉", "JP-28", ["有馬温泉", "ありまおんせん", "arima onsen"], "touristArea"),
    ("軽井沢", "JP-20", ["軽井沢", "かるいざわ", "karuizawa"], "touristArea"),
    ("白川郷", "JP-21", ["白川郷", "しらかわごう", "shirakawago"], "touristArea"),
    ("富良野", "JP-01", ["富良野", "ふらの", "furano"], "touristArea"),
    ("伊豆", "JP-22", ["伊豆", "いず", "izu"], "touristArea"),
    ("箱根", "JP-14", ["箱根", "はこね", "hakone"], "touristArea"),
    ("別府温泉", "JP-44", ["別府温泉", "べっぷおんせん", "beppu"], "touristArea"),
    ("富士山", "JP-19", ["富士山", "ふじさん", "mount fuji"], "touristArea"),
    ("富士山", "JP-22", ["富士山", "ふじさん", "mount fuji"], "touristArea"),
]

FRANCE_JAPANESE_CITIES = {
    "Paris": ["パリ"],
    "Nice": ["ニース"],
    "Cannes": ["カンヌ"],
    "Marseille": ["マルセイユ"],
    "Bordeaux": ["ボルドー"],
    "Strasbourg": ["ストラスブール"],
    "Lyon": ["リヨン"],
    "Toulouse": ["トゥールーズ"],
    "Lille": ["リール"],
    "Nantes": ["ナント"],
    "Montpellier": ["モンペリエ"],
    "Versailles": ["ヴェルサイユ"],
    "Avignon": ["アヴィニョン"],
    "Colmar": ["コルマール"],
    "Annecy": ["アヌシー"],
}

FRANCE_MANUAL_ALIASES = [
    ("Disneyland Paris", "FR-77", ["Disneyland Paris", "ディズニーランド・パリ"]),
    ("Mont-Saint-Michel", "FR-50", ["Mont-Saint-Michel", "モンサンミッシェル"]),
    ("Chamonix", "FR-74", ["Chamonix", "シャモニー"]),
    ("Côte de Nuits", "FR-21", ["Côte de Nuits"]),
    ("Côte d’Azur", "FR-06", ["Côte d’Azur", "コート・ダジュール"]),
    ("Côte d’Azur", "FR-83", ["Côte d’Azur", "コート・ダジュール"]),
]

LANGUAGE_FIELDS = {
    "en": "name_en",
    "ja": "name_ja",
    "es": "name_es",
    "fr": "name_fr",
    "de": "name_de",
    "it": "name_it",
    "pt-BR": "name_pt",
    "ko": "name_ko",
    "zh-Hans": "name_zh",
    "zh-Hant": "name_zht",
    "ru": "name_ru",
}


def normalize_term(value):
    value = unicodedata.normalize("NFKC", value).replace("œ", "oe").replace("Œ", "OE")
    normalized = []
    for character in value:
        # Kana dakuten/handakuten carry meaning and must not be treated like
        # Latin search accents (for example, ベ must not become ヘ).
        if (
            "\u3040" <= character <= "\u30ff"
            or "\u31f0" <= character <= "\u31ff"
        ):
            normalized.append(character)
            continue
        normalized.extend(
            component
            for component in unicodedata.normalize("NFKD", character)
            if not unicodedata.combining(component)
        )
    value = "".join(normalized)
    value = "".join(
        chr(ord(character) + 0x60) if "ぁ" <= character <= "ゖ" else character
        for character in value
    )
    value = re.sub(r"[-'’‐‑–—・]", " ", value)
    value = re.sub(r"[市区町村]$", "", value)
    return re.sub(r"\s+", " ", value).strip().lower()


def alias(
    identifier, country, subdivision, display, terms, alias_type,
    priority=100, ja=None, localized=None
):
    names = {"en": display}
    if ja:
        names["ja"] = ja
    if localized:
        names.update(localized)
    return {
        "id": identifier,
        "countryCode": country,
        "subdivisionCode": subdivision,
        "displayName": display,
        "localizedDisplayNames": names,
        "normalizedTerms": list(dict.fromkeys(normalize_term(term) for term in terms if term)),
        "type": alias_type,
        "priority": priority,
    }


def generate_japan(source_csv, prefecture_json, admin_geojson, output):
    prefectures = json.loads(prefecture_json.read_text())
    geojson = json.loads(admin_geojson.read_text())
    localized_by_code = {}
    for feature in geojson["features"]:
        properties = feature["properties"]
        if properties.get("adm0_a3") != "JPN":
            continue
        localized_by_code[properties["iso_3166_2"]] = {
            language: properties.get(field)
            for language, field in LANGUAGE_FIELDS.items()
            if properties.get(field)
        }
    aliases = []
    for prefecture in prefectures:
        localized = localized_by_code.get(prefecture["id"], {})
        localized.update({
            "en": prefecture["englishName"],
            "ja": prefecture["japaneseName"],
        })
        aliases.append(alias(
            f"jp-pref-{prefecture['id']}",
            "JP",
            prefecture["id"],
            prefecture["japaneseName"],
            [prefecture["japaneseName"], prefecture["englishName"], *localized.values()],
            "subdivision",
            300,
            prefecture["japaneseName"],
            localized,
        ))

    seen = set()
    with source_csv.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            city_code = row["市区町村コード"]
            if city_code in seen:
                continue
            seen.add(city_code)
            prefecture_code = f"JP-{int(row['都道府県コード']):02d}"
            name = row["市区町村名"]
            aliases.append(alias(
                f"jp-city-{city_code}",
                "JP",
                prefecture_code,
                name,
                [name, row["市区町村名カナ"], row["市区町村名ローマ字"]],
                "municipalWard" if name.endswith("区") else "municipality",
                180,
                name,
            ))

    for index, (name, code, terms, alias_type) in enumerate(JAPAN_MANUAL_ALIASES):
        aliases.append(alias(
            f"jp-manual-{index}",
            "JP",
            code,
            name,
            terms,
            alias_type,
            160,
            name,
        ))
    output.write_text(json.dumps(aliases, ensure_ascii=False, separators=(",", ":")) + "\n")
    print(f"Wrote {len(aliases)} Japan search aliases")


def point_line_distance(point, start, end):
    if start == end:
        return math.dist(point, start)
    dx, dy = end[0] - start[0], end[1] - start[1]
    t = max(0, min(1, ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / (dx * dx + dy * dy)))
    return math.dist(point, (start[0] + t * dx, start[1] + t * dy))


def simplify(points, epsilon=0.02):
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


def normalize_france_ring(ring, code):
    points = simplify(ring)
    if code not in OVERSEAS_CODES.values():
        return [
            {"x": round(0.08 + (lon + 5.5) / 15.5 * 0.84, 5),
             "y": round(0.04 + (51.5 - lat) / 10.5 * 0.66, 5)}
            for lon, lat in points
        ]
    slots = {
        "FR-971": (0.03, 0.75), "FR-972": (0.225, 0.75), "FR-973": (0.42, 0.75),
        "FR-974": (0.615, 0.75), "FR-976": (0.81, 0.75),
    }
    x0, y0 = slots[code]
    lons = [point[0] for point in ring]
    lats = [point[1] for point in ring]
    min_lon, max_lon = min(lons), max(lons)
    min_lat, max_lat = min(lats), max(lats)
    width, height = max(max_lon - min_lon, 0.01), max(max_lat - min_lat, 0.01)
    return [
        {"x": round(x0 + 0.02 + (lon - min_lon) / width * 0.145, 5),
         "y": round(y0 + 0.02 + (max_lat - lat) / height * 0.15, 5)}
        for lon, lat in points
    ]


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def generate_france(cog_dir, admin_geojson, output_dir):
    geojson = json.loads(admin_geojson.read_text())
    localized_by_code = {}
    for feature in geojson["features"]:
        properties = feature["properties"]
        if properties.get("adm0_a3") != "FRA":
            continue
        code = OVERSEAS_CODES.get(
            properties.get("iso_3166_2"), properties.get("iso_3166_2")
        )
        localized_by_code[code] = {
            language: properties.get(field)
            for language, field in LANGUAGE_FIELDS.items()
            if properties.get(field)
        }
    regions = {row["REG"]: row["LIBELLE"] for row in read_csv(cog_dir / "v_region_2026.csv")}
    departments_source = read_csv(cog_dir / "v_departement_2026.csv")
    departments = []
    for order, row in enumerate(departments_source):
        code = row["DEP"]
        localized = localized_by_code.get(f"FR-{code}", {})
        localized["fr"] = row["NCCENR"]
        departments.append({
            "id": f"FR-{code}",
            "code": code,
            "nativeName": row["NCCENR"],
            "localizedNames": localized,
            "groupCode": row["REG"],
            "groupName": regions[row["REG"]],
            "displayOrder": order,
        })
    if len(departments) != 101:
        raise ValueError(f"Expected 101 departments, found {len(departments)}")

    valid_codes = {item["id"] for item in departments}
    aliases = []
    for item in departments:
        aliases.append(alias(
            f"fr-dep-{item['code']}", "FR", item["id"], item["nativeName"],
            [
                item["nativeName"], item["code"], item["groupName"],
                *item["localizedNames"].values(),
            ],
            "subdivision", 300, localized=item["localizedNames"],
        ))
    for row in read_csv(cog_dir / "v_commune_2026.csv"):
        code = f"FR-{row['DEP']}"
        if code not in valid_codes:
            continue
        name = row["NCCENR"]
        japanese = FRANCE_JAPANESE_CITIES.get(name, [])
        aliases.append(alias(
            f"fr-city-{row['TYPECOM']}-{row['COM']}",
            "FR", code, name, [name, row["LIBELLE"], *japanese],
            "municipalWard" if row["TYPECOM"] == "ARM" else "municipality",
            180, japanese[0] if japanese else None,
        ))
    for index, (name, code, terms) in enumerate(FRANCE_MANUAL_ALIASES):
        aliases.append(alias(
            f"fr-manual-{index}", "FR", code, name, terms, "touristArea", 160,
            terms[1] if len(terms) > 1 else None,
        ))

    geometries = []
    for feature in geojson["features"]:
        properties = feature["properties"]
        if properties.get("adm0_a3") != "FRA":
            continue
        source_code = properties.get("iso_3166_2")
        code = OVERSEAS_CODES.get(source_code, source_code)
        if code not in valid_codes:
            continue
        polygons = [
            normalize_france_ring(ring, code)
            for ring in rings(feature["geometry"])
            if len(ring) >= 4
        ]
        polygons = [polygon for polygon in polygons if len(polygon) >= 3]
        geometries.append({"code": code, "polygons": polygons})

    if len(geometries) != 101:
        raise ValueError(f"Expected 101 geometries, found {len(geometries)}")
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "france-departments.json").write_text(
        json.dumps(departments, ensure_ascii=False, indent=2) + "\n"
    )
    (output_dir / "france-place-search-index.json").write_text(
        json.dumps(aliases, ensure_ascii=False, separators=(",", ":")) + "\n"
    )
    (output_dir / "france-map.json").write_text(
        json.dumps(sorted(geometries, key=lambda item: item["code"]), separators=(",", ":")) + "\n"
    )
    print(f"Wrote {len(departments)} departments, {len(aliases)} aliases, {len(geometries)} geometries")


def main():
    if len(sys.argv) != 6:
        raise SystemExit(
            "usage: generate_subdivision_data.py JAPAN_CSV PREFECTURES_JSON COG_DIR ADMIN_GEOJSON OUTPUT_DIR"
        )
    japan_csv, prefectures, cog_dir, admin_geojson, output_dir = map(Path, sys.argv[1:])
    generate_japan(
        japan_csv,
        prefectures,
        admin_geojson,
        output_dir / "japan-place-search-index.json",
    )
    generate_france(cog_dir, admin_geojson, output_dir)


if __name__ == "__main__":
    main()
