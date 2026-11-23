"""Build latest.json, the file the download page reads, from a GitHub release.

   usage: latest_release_json.py <release.json> <latest.json>

<release.json> is the output of
   gh release view --json tagName,publishedAt,assets
(no tag argument: that is the repository's LATEST published release).

WHY THE SITE READS A FILE AND NOT THE GITHUB API.  The page wants a human label,
a one-line description, a size and a checksum per platform, and it must be able
to say "no macOS package in this release" rather than show a dead button.  The
release's own asset list carries none of that, so this script derives it, once,
in one place.  The workflow that publishes the result calls this script and
holds no logic of its own.

WHAT IT REFUSES (non-zero exit, message on stderr):
   * a release with no Windows installer.  Windows is the one platform the
     release workflow guarantees, so a payload without one is not a TR4W
     release and publishing it would put a wrong page on the site.
   * an asset whose download URL is not the tagged form
     https://github.com/<owner>/<repo>/releases/download/<tag>/<name>.
     A DRAFT release's assets live under "untagged-<hash>", which the public
     cannot download; that URL must never reach the page.

A PARTIAL RELEASE IS NORMAL.  The release workflow publishes Windows when the
Linux or macOS build is missing.  A platform with no file is listed with
available=false and a reason; a platform with only some of its files (a .pkg
without a .dmg) lists the ones present and names the missing ones.
"""

import json
import re
import sys

SCHEMA = 1

TAG_PATTERN = re.compile(r"^v(\d+\.\d+\.\d+.*)$")

# One row per downloadable file the page offers.  The patterns are the same
# file-name shapes release.yml's "Report which platform artifacts are present"
# step audits; keep the two in step when a file name changes.
PLATFORMS = [
   {
      "key": "windows-x64",
      "label": "Windows",
      "detail": "64-bit Windows",
      "required": True,
      "files": [
         {
            "role": "installer",
            "pattern": r"^tr4w_setup_.+-x64\.exe$",
            "description": "Windows installer for 64-bit Windows. Run it to install or upgrade TR4W.",
         },
      ],
   },
   {
      "key": "macos-aarch64",
      "label": "macOS",
      "detail": "Apple Silicon",
      "required": False,
      "files": [
         {
            "role": "pkg",
            "pattern": r"^tr4w-.+-aarch64-darwin\.pkg$",
            "description": "Installer package for Apple Silicon Macs. Double-click it to place TR4W.app in Applications.",
         },
         {
            "role": "dmg",
            "pattern": r"^tr4w-.+-aarch64-darwin\.dmg$",
            "description": "Disk image for Apple Silicon Macs. Open it and drag TR4W.app to Applications; includes the multi-op server.",
         },
      ],
   },
   {
      "key": "linux-x86_64",
      "label": "Linux",
      "detail": "x86-64",
      "required": False,
      "files": [
         {
            "role": "appimage",
            "pattern": r"^TR4W-.+-x86_64\.AppImage$",
            "description": "Single-file application for 64-bit Linux. Make it executable and run it; see the release notes for the distributions it supports.",
         },
      ],
   },
]

REPORT = {
   "role": "virustotal",
   "pattern": r"^virustotal-report\.md$",
   "description": "VirusTotal scan report for this release's files.",
}


class ReleaseError(Exception):
   pass


def load_assets(release):
   """Return the asset list, rejecting a payload that is not shaped as expected."""
   if not isinstance(release, dict):
      raise ReleaseError("release payload is not a JSON object")
   for field in ("tagName", "publishedAt", "assets"):
      if field not in release:
         raise ReleaseError("release payload has no '%s'" % field)
   if not isinstance(release["assets"], list):
      raise ReleaseError("release payload 'assets' is not a list")
   return release["assets"]


def find_asset(assets, pattern):
   """First asset (by name order, so the answer is stable) whose name matches."""
   matches = sorted(
      (a for a in assets if re.match(pattern, a.get("name", ""))),
      key=lambda a: a["name"],
   )
   if matches:
      return matches[0]
   return None


def describe(asset, spec, tag):
   """One file entry, or an error when the asset cannot be offered to the public."""
   name = asset["name"]
   url = asset.get("url", "")
   marker = "/releases/download/%s/%s" % (tag, name)
   if not (url.startswith("https://github.com/") and url.endswith(marker)):
      raise ReleaseError(
         "asset %s has url %r, not the tagged download form .../releases/download/%s/%s "
         "(a draft release's assets are not downloadable by the public)" % (name, url, tag, name)
      )
   size = asset.get("size")
   if not isinstance(size, int) or size <= 0:
      raise ReleaseError("asset %s has no usable size (%r)" % (name, size))
   digest = asset.get("digest") or ""
   sha256 = None
   if digest.startswith("sha256:") and re.match(r"^[0-9a-f]{64}$", digest[7:]):
      sha256 = digest[7:]
   return {
      "role": spec["role"],
      "name": name,
      "url": url,
      "size": size,
      "sha256": sha256,
      "description": spec["description"],
   }


def build(release):
   assets = load_assets(release)
   tag = release["tagName"]
   m = TAG_PATTERN.match(tag)
   if not m:
      raise ReleaseError("tag %r is not of the form v<major>.<minor>.<patch>" % tag)

   platforms = {}
   for platform in PLATFORMS:
      files = []
      missing = []
      for spec in platform["files"]:
         asset = find_asset(assets, spec["pattern"])
         if asset is None:
            missing.append({
               "role": spec["role"],
               "reason": "No %s was attached to %s." % (spec["role"], tag),
            })
         else:
            files.append(describe(asset, spec, tag))
      if platform["required"] and not files:
         raise ReleaseError("release %s has no %s file; refusing to describe it" % (tag, platform["label"]))
      entry = {
         "label": platform["label"],
         "detail": platform["detail"],
         "available": len(files) > 0,
         "files": files,
         "missing": missing,
      }
      if not files:
         entry["reason"] = "%s has no %s package yet." % (tag, platform["label"])
      platforms[platform["key"]] = entry

   report_asset = find_asset(assets, REPORT["pattern"])
   report = None
   if report_asset is not None:
      report = describe(report_asset, REPORT, tag)

   return {
      "schema": SCHEMA,
      "tag": tag,
      "version": m.group(1),
      "published": release["publishedAt"],
      "release_url": "https://github.com/TR4W/TR4W-D12/releases/tag/%s" % tag,
      "platforms": platforms,
      "virustotal": report,
   }


def main(argv):
   if len(argv) != 3:
      sys.stderr.write(__doc__)
      return 2
   try:
      with open(argv[1], "r", encoding="utf-8") as handle:
         release = json.load(handle)
      result = build(release)
   except (OSError, ValueError, ReleaseError) as problem:
      sys.stderr.write("latest_release_json: %s\n" % problem)
      return 1
   with open(argv[2], "w", encoding="utf-8", newline="\n") as handle:
      json.dump(result, handle, indent=2, sort_keys=False)
      handle.write("\n")
   return 0


if __name__ == "__main__":
   sys.exit(main(sys.argv))
