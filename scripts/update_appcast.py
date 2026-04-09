#!/usr/bin/env python3
"""Insert a new release item into appcast.xml."""
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

def main():
    if len(sys.argv) != 6:
        print("Usage: update_appcast.py <appcast_path> <version> <build_number> <ed_signature> <length>")
        sys.exit(1)

    appcast_path, version, build_number, ed_signature, length = sys.argv[1:]

    # GitHub repo info from environment
    import os
    repo = os.environ.get("GITHUB_REPOSITORY", "uhyrdtrdtfg-creator/mac_dev_app")

    download_url = f"https://github.com/{repo}/releases/download/v{version}/DevToolkit.zip"
    pub_date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S %z")

    sparkle_ns = "http://www.andymatuschak.org/xml-namespaces/sparkle"
    ET.register_namespace("sparkle", sparkle_ns)
    ET.register_namespace("dc", "http://purl.org/dc/elements/1.1/")

    tree = ET.parse(appcast_path)
    channel = tree.find("channel")

    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = f"Version {version}"
    ET.SubElement(item, f"{{{sparkle_ns}}}version").text = build_number
    ET.SubElement(item, f"{{{sparkle_ns}}}shortVersionString").text = version
    ET.SubElement(item, f"{{{sparkle_ns}}}minimumSystemVersion").text = "26.0"
    ET.SubElement(item, "pubDate").text = pub_date

    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", download_url)
    enclosure.set("type", "application/octet-stream")
    enclosure.set(f"{{{sparkle_ns}}}edSignature", ed_signature)
    enclosure.set("length", length)

    ET.indent(tree, space="    ")
    tree.write(appcast_path, encoding="utf-8", xml_declaration=True)

if __name__ == "__main__":
    main()
