import json
from html.parser import HTMLParser
from pathlib import Path

from playwright.sync_api import sync_playwright

WEBSITE_NAME = "https://pressplayz.top/live-tv"
SCRIPT_DIR = Path(__file__).resolve().parent
TARGET_DIR = SCRIPT_DIR / "../../MoviesAPIClient/"

class ChannelCatalogParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.channels = None
        self.sections = None

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag != "astro-island" or attributes.get("component-export") != "ChannelGrid":
            return

        # Astro serializes each value as [type, value]. HTMLParser decodes
        # attribute entities before JSON parsing, so no JavaScript is needed.
        props = json.loads(attributes["props"])
        channels = {}
        sections = {}
        for _, entry in props["channels"][1]:
            channel_id = int(entry["id"][1])
            name = entry["name"][1]
            categories = [value for _, value in entry["categories"][1]]
            channels[channel_id] = {
                "name": name,
                "id": channel_id,
                # Keep the image link only; no image files are downloaded.
                "logo": entry["logo"][1],
                "isAdult": "adult" in categories or "18+" in name,
            }
            # Put each channel in its categories, just like the site's tabs.
            # Channels with multiple categories appear in each matching section.
            for category in categories or ["uncategorized"]:
                sections.setdefault(category, {})[channel_id] = channels[channel_id]
        self.channels = sorted(channels.values(), key=lambda channel: channel["id"])
        # Keep LiveTV as an array, with a name and channel list for each section.
        self.sections = [
            {
                "name": category.title(),
                "channels": sorted(section.values(), key=lambda channel: channel["id"]),
            }
            for category, section in sorted(sections.items())
        ]


def main():
    # API requests download HTML without opening a browser or executing ads,
    # popups, redirects in JavaScript, or embedded players.
    with sync_playwright() as playwright:
        request = playwright.request.new_context()
        try:
            response = request.get(WEBSITE_NAME, timeout=30000)
            if not response.ok:
                raise RuntimeError(f"Channel page returned HTTP {response.status}")
            parser = ChannelCatalogParser()
            parser.feed(response.text())
        finally:
            request.dispose()

    if not parser.channels:
        raise RuntimeError("ChannelGrid catalog missing or empty; existing output was kept.")

    # Resolve the absolute path to the target file
    output_file = (TARGET_DIR / "LiveTV.json").resolve()

    # Strict Constraint: Raise an error if the parent folder is missing
    if not output_file.parent.is_dir():
        raise FileNotFoundError(
            f"Deployment Error: The target parent directory does not exist! "
            f"Ensure '{output_file.parent}' is created before running this script."
        )

    # Clean up the file if it already exists to guarantee a fresh write
    output_file.unlink(missing_ok=True)

    # Write the fresh JSON data
    output_file.write_text(json.dumps({"LiveTV": parser.sections}, indent=4), encoding="utf-8")
    print(f"Extracted {len(parser.channels)} channels to {output_file}!")






if __name__ == "__main__":
    main()
