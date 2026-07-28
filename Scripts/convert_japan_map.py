#!/usr/bin/env python3
"""Extract Japan's 47 prefectures from Natural Earth admin-1 GeoJSON."""

import json
import math
import sys
from pathlib import Path


REGIONS = {
    **{code: "hokkaido" for code in range(1, 2)},
    **{code: "tohoku" for code in range(2, 8)},
    **{code: "kanto" for code in range(8, 15)},
    **{code: "chubu" for code in range(15, 24)},
    **{code: "kinki" for code in range(24, 31)},
    **{code: "chugoku" for code in range(31, 36)},
    **{code: "shikoku" for code in range(36, 40)},
    **{code: "kyushuOkinawa" for code in range(40, 48)},
}

JAPANESE_NAMES = [
    "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
    "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
    "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
    "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
    "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
    "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
    "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県",
]

ENGLISH_NAMES = [
    "Hokkaido", "Aomori", "Iwate", "Miyagi", "Akita", "Yamagata", "Fukushima",
    "Ibaraki", "Tochigi", "Gunma", "Saitama", "Chiba", "Tokyo", "Kanagawa",
    "Niigata", "Toyama", "Ishikawa", "Fukui", "Yamanashi", "Nagano", "Gifu",
    "Shizuoka", "Aichi", "Mie", "Shiga", "Kyoto", "Osaka", "Hyogo", "Nara",
    "Wakayama", "Tottori", "Shimane", "Okayama", "Hiroshima", "Yamaguchi",
    "Tokushima", "Kagawa", "Ehime", "Kochi", "Fukuoka", "Saga", "Nagasaki",
    "Kumamoto", "Oita", "Miyazaki", "Kagoshima", "Okinawa",
]


def point_line_distance(point, start, end):
    if start == end:
        return math.dist(point, start)
    dx, dy = end[0] - start[0], end[1] - start[1]
    t = max(0, min(1, ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / (dx * dx + dy * dy)))
    return math.dist(point, (start[0] + t * dx, start[1] + t * dy))


def simplify(points, epsilon=0.012):
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
    return [
        {
            "x": round((lon - 122.5) / 24.0, 5),
            "y": round((46.5 - lat) / 23.5, 5),
        }
        for lon, lat in simplify(ring)
    ]


def main():
    source, output_dir = Path(sys.argv[1]), Path(sys.argv[2])
    data = json.loads(source.read_text())
    features = {}
    for feature in data["features"]:
        properties = feature["properties"]
        if properties.get("adm0_a3") != "JPN":
            continue
        code = properties.get("iso_3166_2")
        if code:
            features[code] = feature

    if len(features) != 47:
        raise ValueError(f"Expected 47 prefectures, found {len(features)}")

    prefectures, map_prefectures = [], []
    for number in range(1, 48):
        code = f"JP-{number:02d}"
        feature = features[code]
        polygons = [
            normalize(ring)
            for ring in rings(feature["geometry"])
            if len(ring) >= 4
        ]
        polygons = [ring for ring in polygons if len(ring) >= 3]
        prefectures.append({
            "id": code,
            "englishName": ENGLISH_NAMES[number - 1],
            "japaneseName": JAPANESE_NAMES[number - 1],
            "region": REGIONS[number],
        })
        map_prefectures.append({"code": code, "polygons": polygons})

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "prefectures.json").write_text(
        json.dumps(prefectures, ensure_ascii=False, indent=2) + "\n"
    )
    (output_dir / "japan-map.json").write_text(
        json.dumps(map_prefectures, separators=(",", ":")) + "\n"
    )
    print(f"Wrote {len(prefectures)} prefectures")


if __name__ == "__main__":
    main()
