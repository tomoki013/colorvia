# Map data

Colorvia uses the Natural Earth `ne_110m_admin_0_countries` dataset, converted at
build-preparation time into normalized JSON polygons. Natural Earth raster and
vector map data is in the public domain.

- Source: https://www.naturalearthdata.com/downloads/110m-cultural-vectors/
- Terms: https://www.naturalearthdata.com/about/terms-of-use/
- Conversion: `Scripts/convert_world_map.py`

The bundled data omits Antarctica and features without an ISO alpha-2 code.

The Japan map uses the Natural Earth `ne_10m_admin_1_states_provinces` dataset.
Its 47 Japan features are converted to normalized, simplified polygons and
identified by ISO 3166-2 subdivision codes.

- Source: https://www.naturalearthdata.com/downloads/10m-cultural-vectors/
- Conversion: `Scripts/convert_japan_map.py`

The France map uses the same Natural Earth admin-1 dataset. All 101 French
departments are retained: 96 metropolitan departments and Guadeloupe,
Martinique, French Guiana, Réunion, and Mayotte. Overseas geometry is normalized
into labeled inset areas below metropolitan France.

French department and commune names/codes come from Insee's 2026 Code officiel
géographique (COG). The offline Japan municipality search index is generated
from Geolonia's Japanese address CSV, whose source data is based on the Ministry
of Land, Infrastructure, Transport and Tourism address data. Small curated
alias tables add common travel-area and Japanese exonym searches.

- Insee COG: https://www.insee.fr/fr/information/8740222
- Japanese address index: https://github.com/geolonia/japanese-addresses
- Generation: `Scripts/generate_subdivision_data.py`

Spain, South Korea, Egypt, Thailand, and Türkiye use the Natural Earth 10m
admin-1 source, normalized into compact per-country JSON. The source contains
exactly 52, 17, 27, 77, and 81 matching features respectively. Spain's Balearic
Islands, Canary Islands, Ceuta, and Melilla are moved into fixed visual insets.

Regional names include Natural Earth's 11 relevant language fields. Offline
populated-place and alternate-name aliases are derived from the corresponding
GeoNames country dumps (CC BY 4.0), downloaded on 2026-07-28. The generated
indexes are bundled; the app never sends a search query externally.

- GeoNames export: https://download.geonames.org/export/dump/
- GeoNames license: https://www.geonames.org/about.html
- Spain codes: https://www.ine.es/en/daco/daco42/codmun/cod_ccaa_provincia_en.htm
- South Korea regions: https://www.mois.go.kr/eng/sub/a03/citiesProvinces/screen.do
- Thailand administration: https://www.nso.go.th/public/e-book/Statistical-Yearbook/SYB-2025/14/
- Türkiye provinces: https://icisleri.gov.tr/valilikler
- Generation: `Scripts/generate_country_subdivisions.py`

The United States uses the U.S. Census Bureau 2024 1:500,000
state-equivalent cartographic boundary file. Its 56 records provide the 50
states, District of Columbia, Puerto Rico, Guam, U.S. Virgin Islands, American
Samoa, and Northern Mariana Islands. Alaska, Hawaii, and each territory are
placed in visual insets.

- Census cartographic boundaries:
  https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html

Malaysia and Belgium use Natural Earth admin-1 geometry. Malaysia records 13
states and three federal territories. Belgium records its 10 provinces plus
the non-province Brussels-Capital Region as a non-overlapping composite.

Singapore uses all 55 polygons from URA's Master Plan 2019 Planning Area
Boundary (No Sea) dataset. A build-time union groups every Planning Area
exactly once into eight Colorvia travel areas; the source polygons are not
bundled in the app.

- URA planning-area data:
  https://data.gov.sg/datasets/d_4765db0e87b9c86336792efe8a1f7a66/view
- Generation: `Scripts/generate_region_scheme_data.py`
