The script uses these imports:

- `json`, `html.parser`, and `pathlib` are included with Python.
- `playwright` is the only package you need to install. The script uses its HTTP
  request client, so you do not need to install Chromium or any other browser.

Install the dependency:

```shell
python3 -m pip install playwright
```

From the repository root, run:

```shell
cd Scripts/LiveTV
python3 get_live_from_pressplayz.py
```

It downloads the channel directory HTML and reads the embedded Astro catalog
without executing page scripts or opening a browser. It writes
`MoviesAPIClient/LiveTV.json` relative to the repository root.

`LiveTV` contains sections grouped by the site's categories:

```json
{
  "LiveTV": [
    {
      "name": "Basic Cable",
      "channels": [
        { "name": "Animal Planet", "id": 304, "isAdult": false }
      ]
    }
  ]
}
```

Sections are sorted alphabetically, and channels are sorted by ID. A channel
with multiple categories appears in each matching section. Channels without a
category go in `Uncategorized`. Consumers of the previous flat array must now
read each section's `channels` array.
