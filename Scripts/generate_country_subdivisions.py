#!/usr/bin/env python3
"""Generate five definition-driven subdivision catalogs, maps, and offline search indexes."""

import csv
import io
import json
import re
import sys
import unicodedata
import zipfile
from pathlib import Path


COUNTRIES = {
    "ES": {"adm0": "ESP", "count": 52, "native": "es", "admin_column": 11},
    "KR": {"adm0": "KOR", "count": 17, "native": "ko", "admin_column": 10},
    "EG": {"adm0": "EGY", "count": 27, "native": "ar", "admin_column": 10},
    "TH": {"adm0": "THA", "count": 77, "native": "th", "admin_column": 10},
    "TR": {"adm0": "TUR", "count": 81, "native": "tr", "admin_column": 10},
}

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

MANUAL_ALIASES = {
    "ES": [
        ("Marbella", "ES-29", ["Marbella", "マルベーリャ"]),
        ("Ibiza", "ES-07", ["Ibiza", "Eivissa", "イビサ"]),
        ("Tenerife", "ES-38", ["Tenerife", "テネリフェ"]),
    ],
    "KR": [
        ("Gyeongju", "KR-47", ["경주", "Gyeongju", "慶州", "キョンジュ"]),
        ("Suwon", "KR-41", ["수원", "Suwon", "水原", "スウォン"]),
        ("Jeonju", "KR-45", ["전주", "Jeonju", "全州", "チョンジュ"]),
        ("Sokcho", "KR-42", ["속초", "Sokcho", "束草", "ソクチョ"]),
    ],
    "EG": [
        ("Abu Simbel", "EG-ASN", ["Abu Simbel", "أبو سمبل", "アブ・シンベル"]),
        ("Hurghada", "EG-BA", ["Hurghada", "الغردقة", "ハルガダ"]),
        ("Sharm el-Sheikh", "EG-JS", ["Sharm el-Sheikh", "شرم الشيخ", "シャルム・エル・シェイク"]),
        ("Dahab", "EG-JS", ["Dahab", "دهب", "ダハブ"]),
        ("Siwa Oasis", "EG-MT", ["Siwa", "Siwa Oasis", "سيوة", "シワ・オアシス"]),
    ],
    "TH": [
        ("Pattaya", "TH-20", ["Pattaya", "พัทยา", "パタヤ"]),
        ("Koh Samui", "TH-84", ["Koh Samui", "Ko Samui", "เกาะสมุย", "サムイ島"]),
        ("Hua Hin", "TH-77", ["Hua Hin", "หัวหิน", "ホアヒン"]),
        ("Pai", "TH-58", ["Pai", "ปาย", "パーイ"]),
    ],
    "TR": [
        ("Göreme", "TR-50", ["Göreme", "Goreme", "ギョレメ"]),
        ("Pamukkale", "TR-20", ["Pamukkale", "パムッカレ"]),
        ("Ephesus", "TR-35", ["Ephesus", "Efes", "エフェソス"]),
        ("Bodrum", "TR-48", ["Bodrum", "ボドルム"]),
        ("Fethiye", "TR-48", ["Fethiye", "フェティエ"]),
        ("Cappadocia", "TR-50", ["Cappadocia", "Kapadokya", "カッパドキア"]),
        ("Cappadocia", "TR-38", ["Cappadocia", "Kapadokya", "カッパドキア"]),
        ("Cappadocia", "TR-68", ["Cappadocia", "Kapadokya", "カッパドキア"]),
        ("Cappadocia", "TR-51", ["Cappadocia", "Kapadokya", "カッパドキア"]),
    ],
}


def normalize(value):
    value = unicodedata.normalize("NFKC", value).replace("œ", "oe").replace("Œ", "OE")
    output = []
    for character in value:
        if "\u3040" <= character <= "\u30ff" or "\u31f0" <= character <= "\u31ff":
            output.append(character)
        else:
            output.extend(
                component
                for component in unicodedata.normalize("NFKD", character)
                if not unicodedata.combining(component)
            )
    value = "".join(
        chr(ord(character) + 0x60) if "ぁ" <= character <= "ゖ" else character
        for character in output
    )
    value = re.sub(r"[-'’‐‑–—・]", " ", value)
    return re.sub(r"\s+", " ", value).strip().lower().replace("ı", "i")


def rings(geometry):
    if geometry["type"] == "Polygon":
        return [geometry["coordinates"][0]]
    if geometry["type"] == "MultiPolygon":
        return [polygon[0] for polygon in geometry["coordinates"]]
    return []


def country_features(geojson, configuration):
    return [
        feature
        for feature in geojson["features"]
        if feature["properties"].get("adm0_a3") == configuration["adm0"]
    ]


def stable_code(country, properties):
    code = properties["iso_3166_2"]
    if country == "ES":
        if code == "ES-CE":
            return "ES-51"
        if code == "ES-ML":
            return "ES-52"
        suffix = code.split("-", 1)[1]
        province_codes = {
            "A": "03", "AB": "02", "AL": "04", "AV": "05", "B": "08", "BA": "06",
            "BI": "48", "BU": "09", "C": "15", "CA": "11", "CC": "10", "CO": "14",
            "CR": "13", "CS": "12", "CU": "16", "GC": "35", "GI": "17", "GR": "18",
            "GU": "19", "H": "21", "HU": "22", "J": "23", "L": "25", "LE": "24",
            "LO": "26", "LU": "27", "M": "28", "MA": "29", "MU": "30", "NA": "31",
            "O": "33", "OR": "32", "P": "34", "PM": "07", "PO": "36", "S": "39",
            "SA": "37", "SE": "41", "SG": "40", "SO": "42", "SS": "20", "T": "43",
            "TE": "44", "TF": "38", "TO": "45", "V": "46", "VA": "47", "VI": "01",
            "Z": "50", "ZA": "49",
        }
        return f"ES-{province_codes.get(suffix, suffix)}"
    return code


def group_values(country, properties):
    if country == "ES" and properties.get("type_en") == "Autonomous City":
        return "autonomous-cities", {
            "en": "Autonomous Cities",
            "ja": "自治都市",
        }
    if country in {"ES", "TH"}:
        name = properties.get("region") or properties.get("name_en") or properties["name"]
        code = properties.get("region_cod") or normalize(name)
        return code, {"en": name, "ja": name}
    if country == "KR":
        is_city = properties.get("iso_3166_2") in {
            "KR-11", "KR-26", "KR-27", "KR-28",
            "KR-29", "KR-30", "KR-31", "KR-36",
        }
        key = "cities" if is_city else "provinces"
        return key, {
            "en": "Special & Metropolitan Cities" if is_city else "Provinces",
            "ja": "特別市・広域市" if is_city else "道・特別自治道",
        }
    return "", {}


def normalize_geometries(features, country):
    raw = []
    for feature in features:
        code = stable_code(country, feature["properties"])
        raw.append((code, [ring for ring in rings(feature["geometry"]) if len(ring) >= 4]))
    if country == "ES":
        return normalize_spain_geometries(raw)
    all_points = [point for _, polygons in raw for polygon in polygons for point in polygon]
    transform = fitted_transform(all_points, (0.06, 0.06, 0.88, 0.88))
    result = []
    for code, polygons in raw:
        normalized = [transform_ring(polygon, transform) for polygon in polygons]
        result.append({"code": code, "polygons": normalized})
    return sorted(result, key=lambda item: item["code"])


def fitted_transform(points, target):
    min_x = min(point[0] for point in points)
    max_x = max(point[0] for point in points)
    min_y = min(point[1] for point in points)
    max_y = max(point[1] for point in points)
    target_x, target_y, target_width, target_height = target
    span_x, span_y = max_x - min_x, max_y - min_y
    scale = min(target_width / span_x, target_height / span_y)
    width, height = span_x * scale, span_y * scale
    return (
        min_x,
        max_y,
        scale,
        target_x + (target_width - width) / 2,
        target_y + (target_height - height) / 2,
    )


def transform_ring(polygon, transform):
    min_x, max_y, scale, offset_x, offset_y = transform
    return [
        {
            "x": round(offset_x + (point[0] - min_x) * scale, 6),
            "y": round(offset_y + (max_y - point[1]) * scale, 6),
        }
        for point in polygon
    ]


def normalize_spain_geometries(raw):
    inset_groups = [
        ({"ES-07"}, (0.04, 0.79, 0.18, 0.12)),
        ({"ES-35", "ES-38"}, (0.29, 0.79, 0.25, 0.12)),
        ({"ES-51"}, (0.68, 0.82, 0.06, 0.06)),
        ({"ES-52"}, (0.84, 0.82, 0.06, 0.06)),
    ]
    inset_codes = set().union(*(codes for codes, _ in inset_groups))
    main = [(code, polygons) for code, polygons in raw if code not in inset_codes]
    main_points = [point for _, polygons in main for polygon in polygons for point in polygon]
    transforms = {
        code: fitted_transform(main_points, (0.05, 0.04, 0.90, 0.68))
        for code, _ in main
    }
    for codes, target in inset_groups:
        entries = [(code, polygons) for code, polygons in raw if code in codes]
        points = [point for _, polygons in entries for polygon in polygons for point in polygon]
        transform = fitted_transform(points, target)
        transforms.update({code: transform for code, _ in entries})
    return sorted(
        [
            {
                "code": code,
                "polygons": [
                    transform_ring(polygon, transforms[code]) for polygon in polygons
                ],
            }
            for code, polygons in raw
        ],
        key=lambda item: item["code"],
    )


def build_catalog(features, country, configuration):
    catalog = []
    geonames_mapping = {}
    for index, feature in enumerate(sorted(features, key=lambda item: stable_code(country, item["properties"]))):
        properties = feature["properties"]
        code = stable_code(country, properties)
        names = {
            language: properties.get(field)
            for language, field in LANGUAGE_FIELDS.items()
            if properties.get(field)
        }
        native_field = f"name_{configuration['native']}"
        native_name = (
            properties.get(native_field)
            or properties.get("name_local")
            or properties.get("name")
            or names.get("en")
        )
        if country == "KR" and code == "KR-42":
            native_name = "강원특별자치도"
            names.update({
                "en": "Gangwon State",
                "ja": "江原特別自治道",
                "ko": "강원특별자치도",
            })
        if country == "KR" and code == "KR-45":
            native_name = "전북특별자치도"
            names.update({
                "en": "Jeonbuk State",
                "ja": "全北特別自治道",
                "ko": "전북특별자치도",
            })
        group_code, group_names = group_values(country, properties)
        catalog.append({
            "id": code,
            "countryCode": country,
            "code": code.split("-", 1)[1],
            "nativeName": native_name,
            "localizedNames": names,
            "groupCode": group_code,
            "localizedGroupNames": group_names,
            "displayOrder": index,
        })
        geonames_code = (properties.get("gn_a1_code") or "").split(".", 1)[-1]
        if geonames_code:
            geonames_mapping[geonames_code] = code
    return catalog, geonames_mapping


def make_alias(identifier, country, code, display, localized, terms, alias_type, priority):
    return {
        "id": identifier,
        "countryCode": country,
        "subdivisionCode": code,
        "displayName": display,
        "localizedDisplayNames": localized,
        "normalizedTerms": list(dict.fromkeys(normalize(term) for term in terms if term)),
        "type": alias_type,
        "priority": priority,
    }


def build_search(country, catalog, geonames_mapping, archive, configuration):
    aliases = [
        make_alias(
            f"{country.lower()}-subdivision-{item['code']}",
            country,
            item["id"],
            item["nativeName"],
            item["localizedNames"],
            [item["nativeName"], item["code"], item["id"], *item["localizedNames"].values()],
            "subdivision",
            300,
        )
        for item in catalog
    ]
    with zipfile.ZipFile(archive) as zip_file:
        source = io.TextIOWrapper(
            zip_file.open(f"{country}.txt"), encoding="utf-8", newline=""
        )
        for row in csv.reader(source, delimiter="\t"):
            if len(row) < 19 or row[6] not in {"P", "A"}:
                continue
            if row[6] == "A" and row[7] != "ADM2":
                continue
            if row[6] == "P" and int(row[14] or 0) == 0 and not row[7].startswith("PPLA"):
                continue
            target_admin = row[configuration["admin_column"]]
            code = geonames_mapping.get(target_admin)
            if not code:
                continue
            alternate_names = [name for name in row[3].split(",") if name]
            terms = [row[1], row[2], *alternate_names]
            aliases.append(
                make_alias(
                    f"{country.lower()}-place-{row[0]}",
                    country,
                    code,
                    row[1],
                    {"en": row[2] or row[1]},
                    terms,
                    "district" if row[6] == "A" else "municipality",
                    180,
                )
            )
    valid_codes = {item["id"] for item in catalog}
    for index, (name, code, terms) in enumerate(MANUAL_ALIASES[country]):
        if code not in valid_codes:
            print(f"warning: skipping invalid manual alias {country} {name} -> {code}")
            continue
        aliases.append(
            make_alias(
                f"{country.lower()}-manual-{index}",
                country,
                code,
                name,
                {"en": name, "ja": terms[-1]},
                terms,
                "touristArea",
                160,
            )
        )
    return aliases


def main():
    if len(sys.argv) != 8:
        raise SystemExit(
            "usage: generate_country_subdivisions.py ADMIN1_GEOJSON ES.zip KR.zip EG.zip TH.zip TR.zip OUTPUT_DIR"
        )
    geojson = json.loads(Path(sys.argv[1]).read_text())
    archives = dict(zip(COUNTRIES, map(Path, sys.argv[2:7])))
    output = Path(sys.argv[7])
    output.mkdir(parents=True, exist_ok=True)
    for country, configuration in COUNTRIES.items():
        features = country_features(geojson, configuration)
        if len(features) != configuration["count"]:
            raise ValueError(f"{country}: expected {configuration['count']}, found {len(features)}")
        catalog, geonames_mapping = build_catalog(features, country, configuration)
        geometry = normalize_geometries(features, country)
        aliases = build_search(
            country, catalog, geonames_mapping, archives[country], configuration
        )
        prefix = country.lower()
        (output / f"{prefix}-subdivisions.json").write_text(
            json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n"
        )
        (output / f"{prefix}-map.json").write_text(
            json.dumps(geometry, separators=(",", ":")) + "\n"
        )
        (output / f"{prefix}-place-search-index.json").write_text(
            json.dumps(aliases, ensure_ascii=False, separators=(",", ":")) + "\n"
        )
        print(country, len(catalog), len(geometry), len(aliases))


if __name__ == "__main__":
    main()
