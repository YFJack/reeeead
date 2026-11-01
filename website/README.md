# Public website

Static, bilingual English/Chinese pages. No dependencies or build framework; `python3 website/build.py` writes `local/site-release/dist/`. The `local/` directory is deliberately ignored so Site credentials and deployment state cannot enter the app repository.

First generate the launch assets with `marketing/video/voice.py`, `render.py`, and `social.py` (see the launch kit). The build copies only explicit public assets and requires no secrets. The output is a buildless static site; hosting identity is managed separately by Sites.

SEO includes unique page titles/descriptions, canonical URLs, English/Chinese/x-default alternates, Open Graph and Twitter sharing cards, SoftwareApplication structured data, sitemap.xml, and robots.txt. Search engine indexing and ranking are external outcomes, not guaranteed by metadata.

The interactive band is explicitly illustrative. Speech samples are pre-generated MP3s; the browser never receives a provider API key. No analytics, backend, account, or private user data is present.
