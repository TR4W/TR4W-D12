"""Verify or publish the TRMASTER.DTA asset from a public TR4W release."""

import argparse
import hashlib
import json
import subprocess
import tempfile
import time
from pathlib import Path
from urllib.request import Request, urlopen

import trmaster_codec
from pages_deploy import DEFAULT_DEPLOY_URL, publish_files


RELEASE_REPO = "TR4W/TR4W-D12"
ASSET_NAME = "TRMASTER.DTA"
PUBLIC_URL = "https://tr4w.github.io/TRMASTER.DTA"


def release_asset(tag, directory):
   release = subprocess.check_output([
      "gh", "release", "view", f"--repo={RELEASE_REPO}",
      "--json=tagName,isDraft,isPrerelease,publishedAt,assets", "--", tag,
   ])
   details = json.loads(release)
   if details["tagName"] != tag or details["isDraft"] or details["isPrerelease"] or not details["publishedAt"]:
      raise ValueError(f"{tag} must be a published stable release tag")
   if not any(asset["name"] == ASSET_NAME for asset in details["assets"]):
      raise ValueError(f"{tag} has no {ASSET_NAME} release asset")
   subprocess.run([
      "gh", "release", "download", f"--repo={RELEASE_REPO}",
      f"--pattern={ASSET_NAME}", f"--dir={directory}", "--", tag,
   ], check=True)
   return directory / ASSET_NAME


def verify_asset(path):
   data = trmaster_codec.read_dta(path)
   calls = data["calls"]
   if data["end_offset"] != data["file_size"] or not calls:
      raise ValueError(f"{ASSET_NAME} has an invalid end offset or no calls")
   if not any(fields.get("Name") for fields in calls.values()):
      raise ValueError(f"{ASSET_NAME} has no operator names")
   digest = hashlib.sha256(path.read_bytes()).hexdigest()
   print(f"{ASSET_NAME}: {len(calls):,} calls, SHA-256 {digest}", flush=True)
   return digest


def verify_pages(digest):
   deadline = time.monotonic() + 180
   request = Request(PUBLIC_URL, headers={"Cache-Control": "no-cache"})
   while time.monotonic() < deadline:
      try:
         with urlopen(request, timeout=15) as response:
            if hashlib.file_digest(response, "sha256").hexdigest() == digest:
               return
      except OSError:
         # Pages can return 404 until the first deployment finishes.
         pass
      time.sleep(5)
   raise RuntimeError(f"{PUBLIC_URL} has not served the expected SHA-256 yet. "
                      "Check the Pages deployment and rerun the command to verify it.")


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("tag", help="exact tag of the published stable TR4W release")
   parser.add_argument("--publish", action="store_true", help="update the public Pages copy")
   args = parser.parse_args()
   try:
      with tempfile.TemporaryDirectory(prefix="trmaster-") as directory:
         workspace = Path(directory)
         asset = release_asset(args.tag, workspace)
         digest = verify_asset(asset)
         if not args.publish:
            print("Asset verified. Use --publish to update the Pages copy.")
            return 0
         if publish_files([asset], DEFAULT_DEPLOY_URL, f"Publish {ASSET_NAME} from {args.tag}", workspace):
            print("Pushed the Pages source update. Waiting for the public file.", flush=True)
         else:
            print("The Pages source already has this file. Verifying the public file.", flush=True)
         verify_pages(digest)
         print(f"Verified public download at {PUBLIC_URL}")
   except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as error:
      parser.exit(1, f"{parser.prog}: {error}\n")
   return 0


if __name__ == "__main__":
   raise SystemExit(main())
