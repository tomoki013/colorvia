# Map data

Colorvia uses the Natural Earth `ne_110m_admin_0_countries` dataset, converted at
build-preparation time into normalized JSON polygons. Natural Earth raster and
vector map data is in the public domain.

- Source: https://www.naturalearthdata.com/downloads/110m-cultural-vectors/
- Terms: https://www.naturalearthdata.com/about/terms-of-use/
- Conversion: `Scripts/convert_world_map.py`

The bundled data omits Antarctica and features without an ISO alpha-2 code.
