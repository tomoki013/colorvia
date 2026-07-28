#!/usr/bin/env python3
"""Generate the US, Malaysia, Belgium, and Singapore region-scheme resources.

Inputs are intentionally kept out of the app bundle:
- Natural Earth admin-1 GeoJSON (names and MY/BE boundaries)
- U.S. Census Bureau 2024 state-equivalent cartographic boundary shapefile
- URA Master Plan 2019 Planning Area GeoJSON
- GeoNames country dumps

Generation requires pyshp and shapely. The checked-in outputs have no runtime dependency.
"""

import csv
import io
import json
import re
import sys
import unicodedata
import zipfile
from pathlib import Path

import shapefile
from shapely.geometry import MultiPolygon, Polygon, shape
from shapely.ops import unary_union


LANGUAGE_FIELDS = {
    "en": "name_en", "ja": "name_ja", "es": "name_es", "fr": "name_fr",
    "de": "name_de", "it": "name_it", "pt-BR": "name_pt", "ko": "name_ko",
    "zh-Hans": "name_zh", "zh-Hant": "name_zht", "ru": "name_ru",
}

TERRITORIES = {
    "GU": ("Guam", "グアム"),
    "PR": ("Puerto Rico", "プエルトリコ"),
    "VI": ("U.S. Virgin Islands", "アメリカ領ヴァージン諸島"),
    "AS": ("American Samoa", "アメリカ領サモア"),
    "MP": ("Northern Mariana Islands", "北マリアナ諸島"),
}

TERRITORY_SEARCH_TERMS = {
    "GU": ["Guam", "グアム", "괌", "关岛", "關島", "Гуам"],
    "PR": ["Puerto Rico", "プエルトリコ", "푸에르토리코", "波多黎各", "Пуэрто-Рико"],
    "VI": ["U.S. Virgin Islands", "Virgin Islands", "アメリカ領ヴァージン諸島",
           "미국령 버진아일랜드", "美属维尔京群岛", "美屬維爾京群島", "Виргинские Острова"],
    "AS": ["American Samoa", "アメリカ領サモア", "아메리칸사모아", "美属萨摩亚",
           "美屬薩摩亞", "Американское Самоа"],
    "MP": ["Northern Mariana Islands", "北マリアナ諸島", "북마리아나 제도",
           "北马里亚纳群岛", "北馬里亞納群島", "Северные Марианские Острова"],
}

SG_AREAS = {
    "SG-CV-DOWNTOWN": (
        "Downtown & Marina", "ダウンタウン＆マリーナ",
        ["Downtown Core", "Marina East", "Marina South", "Museum", "Outram",
         "Rochor", "Singapore River", "Straits View", "Kallang"],
    ),
    "SG-CV-CENTRAL": (
        "Orchard & Central", "オーチャード＆セントラル",
        ["Orchard", "Newton", "Novena", "Tanglin", "River Valley", "Bukit Timah",
         "Bishan", "Toa Payoh", "Queenstown"],
    ),
    "SG-CV-SOUTH": (
        "Sentosa & Southern Islands", "セントーサ＆南部諸島",
        ["Southern Islands", "Bukit Merah"],
    ),
    "SG-CV-CHANGI": ("Changi", "チャンギ", ["Changi", "Changi Bay"]),
    "SG-CV-EAST": (
        "East Coast", "イーストコースト",
        ["Bedok", "Marine Parade", "Geylang", "Paya Lebar", "Tampines", "Pasir Ris"],
    ),
    "SG-CV-NORTH": (
        "Mandai & North", "マンダイ＆ノース",
        ["Mandai", "Woodlands", "Yishun", "Sembawang", "Simpang", "Sungei Kadut",
         "Lim Chu Kang", "Central Water Catchment"],
    ),
    "SG-CV-NORTHEAST": (
        "North-East", "ノースイースト",
        ["Ang Mo Kio", "Hougang", "North-Eastern Islands", "Punggol", "Seletar",
         "Sengkang", "Serangoon"],
    ),
    "SG-CV-WEST": (
        "West", "ウェスト",
        ["Boon Lay", "Bukit Batok", "Bukit Panjang", "Choa Chu Kang", "Clementi",
         "Jurong East", "Jurong West", "Pioneer", "Tengah", "Tuas",
         "Western Islands", "Western Water Catchment"],
    ),
}

MANUAL_ALIASES = {
    "US": [
        ("New York City", ["US-NY"], ["New York City", "ニューヨーク"]),
        ("Los Angeles", ["US-CA"], ["Los Angeles", "ロサンゼルス"]),
        ("San Francisco", ["US-CA"], ["San Francisco", "サンフランシスコ"]),
        ("Las Vegas", ["US-NV"], ["Las Vegas", "ラスベガス"]),
        ("Miami", ["US-FL"], ["Miami", "マイアミ"]),
        ("Chicago", ["US-IL"], ["Chicago", "シカゴ"]),
        ("Seattle", ["US-WA"], ["Seattle", "シアトル"]),
        ("Honolulu", ["US-HI"], ["Honolulu", "ホノルル"]),
        ("Washington, D.C.", ["US-DC"], ["Washington DC", "ワシントンD.C."]),
        ("Grand Canyon", ["US-AZ"], ["Grand Canyon", "グランドキャニオン"]),
        ("Tumon", ["US-GU"], ["Tumon", "タモン"]),
        ("Hagåtña", ["US-GU"], ["Hagåtña", "Hagatna", "ハガニア"]),
        ("Saipan", ["US-MP"], ["Saipan", "サイパン"]),
        ("San Juan", ["US-PR"], ["San Juan", "サンフアン"]),
        ("Yellowstone", ["US-WY", "US-MT", "US-ID"],
         ["Yellowstone", "Yellowstone National Park", "イエローストーン"]),
    ],
    "MY": [
        ("Kuala Lumpur", ["MY-14"], ["Kuala Lumpur", "クアラルンプール"]),
        ("Putrajaya", ["MY-16"], ["Putrajaya", "プトラジャヤ"]),
        ("George Town", ["MY-07"], ["George Town", "ジョージタウン"]),
        ("Penang", ["MY-07"], ["Penang", "Pulau Pinang", "ペナン"]),
        ("Melaka", ["MY-04"], ["Melaka", "Malacca", "マラッカ"]),
        ("Johor Bahru", ["MY-01"], ["Johor Bahru", "ジョホールバル"]),
        ("Langkawi", ["MY-02"], ["Langkawi", "ランカウイ"]),
        ("Kota Kinabalu", ["MY-12"], ["Kota Kinabalu", "コタキナバル"]),
        ("Mount Kinabalu", ["MY-12"], ["Mount Kinabalu", "キナバル山"]),
        ("Kuching", ["MY-13"], ["Kuching", "クチン"]),
        ("Cameron Highlands", ["MY-06"], ["Cameron Highlands"]),
    ],
    "BE": [
        ("Brussels", ["BE-BRU"], ["Brussels", "Bruxelles", "Brussel", "ブリュッセル"]),
        ("Bruges", ["BE-VWV"], ["Bruges", "Brugge", "ブルージュ"]),
        ("Ghent", ["BE-VOV"], ["Ghent", "Gent", "Gand", "ゲント"]),
        ("Antwerp", ["BE-VAN"], ["Antwerp", "Antwerpen", "Anvers", "アントワープ"]),
        ("Leuven", ["BE-VBR"], ["Leuven", "Louvain", "ルーヴェン"]),
        ("Hasselt", ["BE-VLI"], ["Hasselt", "ハッセルト"]),
        ("Charleroi", ["BE-WHT"], ["Charleroi", "シャルルロワ"]),
        ("Liège", ["BE-WLG"], ["Liège", "Liege", "Luik", "リエージュ"]),
        ("Namur", ["BE-WNA"], ["Namur", "Namen", "ナミュール"]),
        ("Waterloo", ["BE-WBR"], ["Waterloo", "ワーテルロー"]),
        ("Dinant", ["BE-WNA"], ["Dinant", "ディナン"]),
        ("Durbuy", ["BE-WLX"], ["Durbuy", "デュルビュイ"]),
    ],
    "SG": [
        ("Marina Bay", ["SG-CV-DOWNTOWN"],
         ["Marina Bay", "マリーナベイ", "마리나 베이", "滨海湾", "濱海灣",
          "Марина-Бэй", "Bahía Marina", "Baie Marina"]),
        ("Merlion", ["SG-CV-DOWNTOWN"], ["Merlion", "マーライオン"]),
        ("Chinatown", ["SG-CV-DOWNTOWN"], ["Chinatown", "チャイナタウン"]),
        ("Little India", ["SG-CV-DOWNTOWN"], ["Little India", "リトルインディア"]),
        ("Bugis", ["SG-CV-DOWNTOWN"], ["Bugis", "ブギス"]),
        ("Clarke Quay", ["SG-CV-DOWNTOWN"], ["Clarke Quay", "クラークキー"]),
        ("Gardens by the Bay", ["SG-CV-DOWNTOWN"], ["Gardens by the Bay"]),
        ("Marina Bay Sands", ["SG-CV-DOWNTOWN"], ["Marina Bay Sands"]),
        ("Orchard", ["SG-CV-CENTRAL"], ["Orchard", "Orchard Road", "オーチャード"]),
        ("Singapore Botanic Gardens", ["SG-CV-CENTRAL"],
         ["Singapore Botanic Gardens", "Botanic Gardens", "植物園"]),
        ("Sentosa", ["SG-CV-SOUTH"],
         ["Sentosa", "セントーサ", "센토사", "圣淘沙", "聖淘沙", "Сентоса"]),
        ("Universal Studios Singapore", ["SG-CV-SOUTH"],
         ["Universal Studios Singapore", "USS", "ユニバーサル・スタジオ"]),
        ("Changi Airport", ["SG-CV-CHANGI"],
         ["Changi Airport", "Singapore Changi Airport", "チャンギ国際空港",
          "Aeropuerto de Changi", "Aéroport de Changi", "Flughafen Changi",
          "Aeroporto di Changi", "Aeroporto de Changi", "창이 공항", "樟宜机场",
          "樟宜機場", "Аэропорт Чанги"]),
        ("Jewel", ["SG-CV-CHANGI"], ["Jewel", "Jewel Changi Airport", "ジュエル"]),
        ("East Coast Park", ["SG-CV-EAST"], ["East Coast Park"]),
        ("Katong", ["SG-CV-EAST"], ["Katong", "カトン"]),
        ("Joo Chiat", ["SG-CV-EAST"], ["Joo Chiat", "ジョーチアット"]),
        ("Night Safari", ["SG-CV-NORTH"],
         ["Night Safari", "ナイトサファリ", "Safari nocturno", "Safari de nuit",
          "Nachtsafari", "Safari notturno", "Safári Noturno", "나이트 사파리",
          "夜间野生动物园", "夜間野生動物園", "Ночное сафари"]),
        ("Singapore Zoo", ["SG-CV-NORTH"], ["Singapore Zoo", "シンガポール動物園"]),
        ("Bird Paradise", ["SG-CV-NORTH"], ["Bird Paradise"]),
        ("Punggol", ["SG-CV-NORTHEAST"], ["Punggol", "プンゴル"]),
        ("Jurong", ["SG-CV-WEST"],
         ["Jurong", "ジュロン", "주롱", "裕廊", "Джуронг"]),
    ],
}


def normalize(value):
    value = unicodedata.normalize("NFKC", value).replace("œ", "oe").replace("Œ", "OE")
    value = "".join(
        c for c in unicodedata.normalize("NFKD", value) if not unicodedata.combining(c)
    )
    value = re.sub(r"[-'’‐‑–—・]", " ", value)
    return re.sub(r"\s+", " ", value).strip().lower()


def language_fallbacks(names, fallback):
    return {language: names.get(language) or fallback for language in LANGUAGE_FIELDS}


def polygons(geometry):
    if isinstance(geometry, Polygon):
        return [list(geometry.exterior.coords)]
    if isinstance(geometry, MultiPolygon):
        return [list(part.exterior.coords) for part in geometry.geoms]
    return [list(part.exterior.coords) for part in geometry.geoms if isinstance(part, Polygon)]


def fitted_transform(points, target):
    min_x, max_x = min(p[0] for p in points), max(p[0] for p in points)
    min_y, max_y = min(p[1] for p in points), max(p[1] for p in points)
    x, y, width, height = target
    scale = min(width / max(max_x - min_x, 1e-9), height / max(max_y - min_y, 1e-9))
    actual_width, actual_height = (max_x - min_x) * scale, (max_y - min_y) * scale
    return min_x, max_y, scale, x + (width - actual_width) / 2, y + (height - actual_height) / 2


def map_items(geometries, targets):
    transforms = {}
    for codes, target in targets:
        points = [p for code in codes for ring in polygons(geometries[code]) for p in ring]
        transform = fitted_transform(points, target)
        transforms.update({code: transform for code in codes})
    result = []
    for code, geometry in geometries.items():
        min_x, max_y, scale, offset_x, offset_y = transforms[code]
        transformed = []
        for ring in polygons(geometry.simplify(0.005, preserve_topology=True)):
            transformed.append([
                {"x": round(offset_x + (p[0] - min_x) * scale, 6),
                 "y": round(offset_y + (max_y - p[1]) * scale, 6)}
                for p in ring
            ])
        result.append({"code": code, "polygons": transformed})
    return sorted(result, key=lambda item: item["code"])


def source_unit(code, country, level):
    return {
        "id": code, "countryCode": country, "sourceCode": code.split("-", 1)[-1],
        "sourceLevel": level, "geometryResourceID": code,
    }


def region(code, country, native, names, group, group_names, order, semantic, sources=None):
    return {
        "id": code, "countryCode": country, "code": code.split("-", 1)[-1],
        "nativeName": native, "localizedNames": names, "sourceUnitIDs": sources or [code],
        "groupCode": group, "localizedGroupNames": group_names, "displayOrder": order,
        "semanticType": semantic,
    }


def alias(identifier, country, targets, display, terms, kind="touristArea", priority=180):
    return {
        "id": identifier, "countryCode": country, "targetRegionIDs": targets,
        "nativeDisplayName": display, "localizedDisplayNames": {"en": display},
        "normalizedTerms": list(dict.fromkeys(normalize(term) for term in terms)),
        "type": kind, "priority": priority,
    }


def natural_earth_catalog(features, country):
    catalog, geometries, geonames = [], {}, {}
    for index, feature in enumerate(sorted(features, key=lambda f: f["properties"]["iso_3166_2"])):
        props = feature["properties"]
        code = props["iso_3166_2"]
        names = {lang: props.get(field) for lang, field in LANGUAGE_FIELDS.items() if props.get(field)}
        native = props.get("name_local") or props.get("name") or names.get("en")
        if country == "MY":
            federal = props.get("type_en") == "Federal Territory"
            group = "federal-territories" if federal else "states"
            group_names = {
                "en": "Federal Territories" if federal else "States",
                "ja": "連邦直轄領" if federal else "州",
            }
        else:
            region_name = props.get("region") or "Brussels"
            group = {"Flemish": "flanders", "Walloon": "wallonia"}.get(region_name, "brussels")
            group_names = {
                "en": {"flanders": "Flanders", "wallonia": "Wallonia", "brussels": "Brussels"}[group],
                "ja": {"flanders": "フランデレン", "wallonia": "ワロン", "brussels": "ブリュッセル"}[group],
            }
        names = language_fallbacks(names, native)
        catalog.append(region(code, country, native, names, group, group_names, index,
                              "administrative"))
        geometries[code] = shape(feature["geometry"])
        gn = (props.get("gn_a1_code") or "").split(".", 1)[-1]
        if gn:
            geonames[gn] = code
    return catalog, geometries, geonames


def search_index(country, catalog, geonames_mapping, archive):
    aliases = [
        alias(f"{country.lower()}-region-{item['code']}", country, [item["id"]],
              item["nativeName"], [item["id"], item["code"], item["nativeName"],
              *item["localizedNames"].values()], "region", 300)
        for item in catalog
    ]
    if archive and archive.exists():
        with zipfile.ZipFile(archive) as zf:
            source = io.TextIOWrapper(zf.open(f"{country}.txt"), encoding="utf-8", newline="")
            for row in csv.reader(source, delimiter="\t"):
                if len(row) < 19 or row[6] != "P":
                    continue
                # Keep the offline index useful without bundling every named hamlet.
                if int(row[14] or 0) < 5_000 and not row[7].startswith("PPLA"):
                    continue
                key = row[10]
                target = geonames_mapping.get(key)
                if not target:
                    continue
                terms = [row[1], row[2], *[name for name in row[3].split(",") if name]]
                aliases.append(alias(f"{country.lower()}-place-{row[0]}", country, [target],
                                     row[1], terms, "municipality", 160))
    for index, (display, targets, terms) in enumerate(MANUAL_ALIASES[country]):
        aliases.append(alias(f"{country.lower()}-manual-{index}", country, targets,
                             display, terms))
    return aliases


def build_us(shapefile_path, natural_earth, geonames_zip):
    ne_features = [f for f in natural_earth["features"] if f["properties"].get("adm0_a3") == "USA"]
    ne_by_code = {f["properties"]["iso_3166_2"]: f for f in ne_features}
    reader = shapefile.Reader(str(shapefile_path))
    shapes = {}
    names = {}
    for record, source_shape in zip(reader.records(), reader.shapes()):
        code = f"US-{record.STUSPS}"
        shapes[code] = shape(source_shape.__geo_interface__)
        names[code] = record.NAME
    if set(shapes) != {f"US-{code}" for code in [
        "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA",
        "KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ",
        "NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT",
        "VA","WA","WV","WI","WY","DC","GU","PR","VI","AS","MP",
    ]}:
        raise ValueError("Census state-equivalent source does not contain exactly 56 targets")
    states = sorted(code for code in shapes if code[3:] not in TERRITORIES)
    territories = [f"US-{code}" for code in ["GU", "PR", "VI", "AS", "MP"]]
    catalog = []
    for code in states + territories:
        suffix = code[3:]
        ne = ne_by_code.get(code, {}).get("properties", {})
        english, japanese = TERRITORIES.get(suffix, (names[code], ne.get("name_ja")))
        localized = {lang: ne.get(field) for lang, field in LANGUAGE_FIELDS.items() if ne.get(field)}
        localized["en"] = english
        if japanese:
            localized["ja"] = japanese
        localized = language_fallbacks(localized, english)
        is_territory = suffix in TERRITORIES
        catalog.append(region(
            code, "US", english, localized,
            "territories" if is_territory else "states-dc",
            {"en": "U.S. Territories" if is_territory else "States & D.C.",
             "ja": "米国領" if is_territory else "州・ワシントンD.C."},
            len(catalog), "territory" if is_territory else "administrative",
        ))
    main = [code for code in states if code not in {"US-AK", "US-HI"}]
    targets = [
        (main, (0.04, 0.03, 0.92, 0.57)),
        (["US-AK"], (0.04, 0.65, 0.23, 0.19)),
        (["US-HI"], (0.30, 0.70, 0.14, 0.10)),
    ]
    for index, code in enumerate(territories):
        targets.append(([code], (0.48 + index * 0.10, 0.68, 0.08, 0.13)))
    geonames = {code[3:]: code for code in states}
    us_search = search_index("US", catalog, geonames, geonames_zip)
    for suffix, terms in TERRITORY_SEARCH_TERMS.items():
        us_search.append(alias(
            f"us-territory-{suffix.lower()}", "US", [f"US-{suffix}"],
            TERRITORIES[suffix][0], terms, "region", 300,
        ))
    return (
        catalog,
        [source_unit(item["id"], "US", "state-equivalent") for item in catalog],
        map_items(shapes, targets),
        us_search,
    )


def build_singapore(source_geojson):
    features = source_geojson["features"]
    if len(features) != 55:
        raise ValueError(f"Singapore: expected 55 Planning Areas, found {len(features)}")
    by_name = {
        feature["properties"]["PLN_AREA_N"].title(): shape(feature["geometry"])
        for feature in features
    }
    expected = set(by_name)
    assigned = [name for _, _, names in SG_AREAS.values() for name in names]
    if len(assigned) != len(set(assigned)):
        raise ValueError("Singapore: a Planning Area is assigned more than once")
    if set(assigned) != expected:
        raise ValueError(f"Singapore assignment mismatch: {sorted(expected ^ set(assigned))}")
    sources = [
        source_unit(f"SG-PA-{re.sub('[^A-Z0-9]+', '-', name.upper()).strip('-')}",
                    "SG", "planning-area")
        for name in sorted(expected)
    ]
    source_ids = {name: unit["id"] for name, unit in zip(sorted(expected), sources)}
    catalog, geometries = [], {}
    for order, (code, (english, japanese, names)) in enumerate(SG_AREAS.items()):
        catalog.append(region(
            code, "SG", english, language_fallbacks({"en": english, "ja": japanese}, english),
            "", {}, order,
            "travelArea", [source_ids[name] for name in names],
        ))
        geometries[code] = unary_union([by_name[name] for name in names])
    all_codes = list(geometries)
    aliases = [
        alias(f"sg-area-{index}", "SG", [item["id"]], item["nativeName"],
              [item["nativeName"], *item["localizedNames"].values()], "region", 300)
        for index, item in enumerate(catalog)
    ]
    for name in sorted(expected):
        target = next(item["id"] for item in catalog if source_ids[name] in item["sourceUnitIDs"])
        aliases.append(alias(f"sg-planning-{normalize(name).replace(' ', '-')}", "SG",
                             [target], name, [name], "district", 220))
    for index, (display, targets, terms) in enumerate(MANUAL_ALIASES["SG"]):
        aliases.append(alias(f"sg-manual-{index}", "SG", targets, display, terms))
    return catalog, sources, map_items(geometries, [(all_codes, (0.05, 0.08, 0.90, 0.84))]), aliases


def write_resources(output, country, catalog, sources, geometry, aliases):
    prefix = country.lower()
    values = {
        f"{prefix}-subdivisions.json": catalog,
        f"{prefix}-source-regions.json": sources,
        f"{prefix}-map.json": geometry,
        f"{prefix}-place-search-index.json": aliases,
    }
    if country == "SG":
        values["sg-planning-areas.json"] = sources
    for filename, value in values.items():
        (output / filename).write_text(
            json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n"
        )
    print(country, len(catalog), len(sources), len(geometry), len(aliases))


def main():
    if len(sys.argv) != 9:
        raise SystemExit(
            "usage: generate_region_scheme_data.py ADMIN1_GEOJSON CENSUS_SHP "
            "SG_PLANNING_GEOJSON US.zip MY.zip BE.zip OUTPUT_DIR"
        )
    natural_earth = json.loads(Path(sys.argv[1]).read_text())
    census_shape = Path(sys.argv[2])
    singapore = json.loads(Path(sys.argv[3]).read_text())
    archives = {"US": Path(sys.argv[4]), "MY": Path(sys.argv[5]), "BE": Path(sys.argv[6])}
    output = Path(sys.argv[7])
    # The eighth argument is reserved for compatibility with generation wrappers.
    if sys.argv[8] != "--write":
        raise SystemExit("last argument must be --write")
    output.mkdir(parents=True, exist_ok=True)

    write_resources(output, "US", *build_us(census_shape, natural_earth, archives["US"]))
    for country, adm0, target in [("MY", "MYS", (0.05, 0.06, 0.90, 0.86)),
                                  ("BE", "BEL", (0.08, 0.05, 0.84, 0.88))]:
        features = [f for f in natural_earth["features"] if f["properties"].get("adm0_a3") == adm0]
        expected = 16 if country == "MY" else 11
        if len(features) != expected:
            raise ValueError(f"{country}: expected {expected}, found {len(features)}")
        catalog, geometries, geonames = natural_earth_catalog(features, country)
        if country == "MY":
            peninsula = [code for code in geometries if code not in {"MY-12", "MY-13", "MY-15"}]
            targets = [
                (peninsula, (0.04, 0.06, 0.43, 0.82)),
                (["MY-12", "MY-13"], (0.50, 0.13, 0.45, 0.67)),
                (["MY-15"], (0.74, 0.74, 0.12, 0.12)),
            ]
        else:
            targets = [(list(geometries), target)]
        sources = [source_unit(item["id"], country, "admin-1") for item in catalog]
        write_resources(
            output, country, catalog, sources, map_items(geometries, targets),
            search_index(country, catalog, geonames, archives[country]),
        )
    write_resources(output, "SG", *build_singapore(singapore))


if __name__ == "__main__":
    main()
