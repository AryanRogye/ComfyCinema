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
without executing page scripts or opening a browser. It writes `channels.json`
in the current working directory, preserving the `LiveTV` output structure.
