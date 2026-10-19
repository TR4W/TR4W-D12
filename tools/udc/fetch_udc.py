"""Download N1MM Logger+ User Defined Contest (UDC) files into a local cache.

Run:  python tools/udc/fetch_udc.py [--cache DIR] [--delay SECONDS] [--limit N]

WHAT IT DOES
   1. Walks every page of the N1MM download library's "User Defined
      Contests" category and records each entry (title, date, author,
      description, page URL).
   2. For each entry, opens its page, finds the download form and downloads
      the .udc / .zip ONCE into <cache>/files/.  A file already in the cache
      is skipped, so an interrupted run resumes where it stopped.
   3. Scrapes the "Setup User Defined Contests" manual page: display name,
      description and file name of each contest.

OUTPUT (all under the cache directory, which is gitignored: the files are
third-party and this repository is public)
   files/<name>            the downloaded .udc or .zip, byte for byte
   manifest.json           one record per listing entry + its download result
   display_names.json      one record per heading on the manual page

THE DOWNLOAD IS A FORM POST.  A GET of the file URL returns the HTML page.
The entry page carries <form action=".../mmfile/get/file/NAME"> with a
per-page nonce and the entry id; POSTing those (with the session cookie from
the page fetch) returns the file as application/octet-stream.

Downloaded content is treated as DATA.  Nothing here executes it, and
parse_udc.py is the only reader.  Standard library only.
"""

import argparse
import hashlib
import html
import http.cookiejar
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CACHE = os.path.join(HERE, "cache")

SITE = "https://n1mmwp.hamdocs.com"
LISTING_URL = (SITE + "/mmfiles/categories/userdefinedcontests/"
               "?cmdm_sort=newest&cmdm_view=list")
DISPLAY_URL = SITE + "/manual-supported/contests-setup/setup-udc-contests/"

USER_AGENT = ("Mozilla/5.0 (compatible; TR4W-tools-udc-fetch/1.0; "
              "+https://github.com/TR4W/TR4W-D12)")
MAX_DOWNLOAD_BYTES = 25 * 1024 * 1024
MAX_PAGE_BYTES = 8 * 1024 * 1024
RETRIES = 4


class Fetcher:
   """One polite HTTP session: cookies kept, fixed delay, retry with backoff."""

   def __init__(self, delay):
      self.delay = delay
      self.last = 0.0
      jar = http.cookiejar.CookieJar()
      self.opener = urllib.request.build_opener(
         urllib.request.HTTPCookieProcessor(jar))
      self.opener.addheaders = [("User-Agent", USER_AGENT),
                                ("Accept-Language", "en")]

   def _wait(self):
      gap = time.time() - self.last
      if gap < self.delay:
         time.sleep(self.delay - gap)
      self.last = time.time()

   def request(self, url, data=None, referer=None, limit=MAX_PAGE_BYTES):
      """Return (body_bytes, headers).  Raises the last error after retries."""
      last_error = None
      for attempt in range(RETRIES):
         self._wait()
         req = urllib.request.Request(url, data=data)
         if referer:
            req.add_header("Referer", referer)
         try:
            with self.opener.open(req, timeout=60) as resp:
               body = resp.read(limit + 1)
               if len(body) > limit:
                  raise ValueError("response larger than %d bytes" % limit)
               return body, resp.headers
         except urllib.error.HTTPError as err:
            last_error = err
            # A 4xx other than 429/408 will not improve by waiting.
            if err.code < 500 and err.code not in (408, 429):
               raise
         except (urllib.error.URLError, OSError) as err:
            last_error = err
         backoff = 2 ** (attempt + 1)
         log("   retry %d after %ss: %s" % (attempt + 1, backoff, last_error))
         time.sleep(backoff)
      raise last_error


def log(text):
   print(text, flush=True)


def strip_tags(fragment):
   text = re.sub(r"<[^>]+>", " ", fragment)
   return re.sub(r"\s+", " ", html.unescape(text)).strip()


# ---------------------------------------------------------------- listing

def parse_listing_page(page_html):
   """Entries on one listing page.  Regex over a stable plugin template."""
   start = page_html.find("cmdm-archive-items")
   if start < 0:
      return []
   end = page_html.find("cmdm-pagination", start)
   body = page_html[start:end if end > 0 else len(page_html)]
   entries = []
   for block in body.split("</li>"):
      title = re.search(r'cmdm-list-item-title">(.*?)</span>', block, re.S)
      if not title:
         continue
      href = re.search(r'<a href="([^"]+/mmfiles/[^"]+)"', block)
      desc = re.search(r'cmdm-list-item-desc">(.*?)<a [^>]*cmdm_read_more_btn'
                       r'|cmdm-list-item-desc">(.*?)</div>', block, re.S)
      desc_text = ""
      if desc:
         desc_text = strip_tags(desc.group(1) or desc.group(2) or "")
         # The hidden remainder of a long description sits in a span.
         more = re.search(r'cmdm_readmore_content"[^>]*>(.*?)</span>',
                          block, re.S)
         if more:
            desc_text = (desc_text + " " + strip_tags(more.group(1))).strip()
      author = re.search(r'CMDM-author-link"[^>]*>(.*?)</a>', block, re.S)
      count = re.search(r"(\d+)\s+downloads", block)
      date = re.search(r'cmdm-publish-date">([^<]*)<', block)
      page_url = html.unescape(href.group(1)) if href else ""
      entries.append({
         "title": strip_tags(title.group(1)),
         "date": date.group(1).strip() if date else "",
         "page_url": page_url,
         "slug": page_url.rstrip("/").rsplit("/", 1)[-1] if page_url else "",
         "author": strip_tags(author.group(1)) if author else "",
         "site_download_count": int(count.group(1)) if count else None,
         "description": desc_text,
      })
   return entries


def listing_page_urls(first_html):
   """Pagination links on page 1, in order (page 2 onward)."""
   urls = []
   for href in re.findall(r'<a href="([^"]*/page/\d+/[^"]*)"', first_html):
      href = html.unescape(href)
      if href not in urls:
         urls.append(href)
   return urls


def fetch_listing(fetcher):
   entries = []
   seen = set()
   body, _ = fetcher.request(LISTING_URL)
   first = body.decode("utf-8", "replace")
   total = re.search(r"Showing\s+\d+-\d+\s+of\s+(\d+)", first)
   pages = [LISTING_URL] + listing_page_urls(first)
   log("listing: site says %s entries, %d pages" %
       (total.group(1) if total else "?", len(pages)))
   for index, url in enumerate(pages):
      if index == 0:
         page_html = first
      else:
         body, _ = fetcher.request(url)
         page_html = body.decode("utf-8", "replace")
      page_entries = parse_listing_page(page_html)
      fresh = 0
      for entry in page_entries:
         key = entry["slug"] or entry["title"]
         if key in seen:
            continue
         seen.add(key)
         entries.append(entry)
         fresh += 1
      log("   page %d: %d entries (%d new)" % (index + 1, len(page_entries),
                                               fresh))
   return entries, (int(total.group(1)) if total else None)


# --------------------------------------------------------------- download

def safe_filename(name):
   """A bare, harmless file name from a URL tail (never a path)."""
   name = urllib.parse.unquote(name)
   name = os.path.basename(name.replace("\\", "/"))
   name = re.sub(r"[^A-Za-z0-9._ +()#-]", "_", name).strip(" .")
   return name or "unnamed"


def find_download_form(page_html):
   form = re.search(r'<form[^>]*class="CMDM-downloadForm"[^>]*action="([^"]+)"'
                    r'(.*?)</form>', page_html, re.S)
   if not form:
      return None
   fields = dict(re.findall(
      r'<input type="hidden" name="([^"]+)" value="([^"]*)"', form.group(2)))
   return html.unescape(form.group(1)), fields


def download_entry(fetcher, entry, files_dir, taken):
   """Fill entry['download_url'], ['file_name'], ['status'] ...  Never raises."""
   try:
      body, _ = fetcher.request(entry["page_url"])
      found = find_download_form(body.decode("utf-8", "replace"))
      if not found:
         entry["status"] = "no-download-form"
         return
      action, fields = found
      entry["download_url"] = action
      name = safe_filename(action.rsplit("/", 1)[-1])
      owner = taken.get(name)
      if owner and owner != entry["slug"]:
         name = safe_filename(entry["slug"] + "__" + name)
      entry["file_name"] = name
      path = os.path.join(files_dir, name)
      if os.path.isfile(path) and os.path.getsize(path) > 0:
         entry["status"] = "cached"
         taken[name] = entry["slug"]
         return
      data = urllib.parse.urlencode(fields).encode("ascii")
      payload, headers = fetcher.request(
         action, data=data, referer=entry["page_url"],
         limit=MAX_DOWNLOAD_BYTES)
      ctype = headers.get("Content-Type", "")
      if "text/html" in ctype.lower() or not payload:
         entry["status"] = "not-a-file (%s, %d bytes)" % (ctype, len(payload))
         return
      with open(path, "wb") as handle:
         handle.write(payload)
      taken[name] = entry["slug"]
      entry["status"] = "downloaded"
      entry["size"] = len(payload)
      entry["sha256"] = hashlib.sha256(payload).hexdigest()
   except Exception as err:  # noqa: BLE001 - log and keep going, by design
      entry["status"] = "error: %s" % err


# ------------------------------------------------------------ display page

def parse_display_page(page_html):
   """One record per <h3> in the entry content of the manual page."""
   start = page_html.find('class="entry-content"')
   body = page_html[start if start > 0 else 0:]
   parts = re.split(r"(?=<h3[ >])", body)
   records = []
   for part in parts[1:]:
      head = re.match(r"<h3[^>]*>(.*?)</h3>", part, re.S)
      if not head:
         continue
      link = re.search(r'<a href="([^"]+/mmfiles/[^"]+)"', head.group(1))
      rest = part[head.end():]
      paragraphs = [strip_tags(p) for p in
                    re.findall(r"<p[^>]*>(.*?)</p>", rest, re.S)]
      items = [strip_tags(i) for i in
               re.findall(r"<li[^>]*>(.*?)</li>", rest, re.S)]
      files = []
      for item in items:
         match = re.match(r"file\s*name\s*:\s*(.+)$", item, re.I)
         if match:
            files.append(match.group(1).strip())
      records.append({
         "display_name": strip_tags(head.group(1)),
         "page_url": html.unescape(link.group(1)) if link else "",
         "description": " ".join(paragraphs),
         "list_items": items,
         "filenames": files,
      })
   return records


# -------------------------------------------------------------------- main

def write_json(path, data):
   tmp = path + ".tmp"
   with open(tmp, "w", encoding="utf-8", newline="\n") as handle:
      json.dump(data, handle, indent=3, ensure_ascii=False)
   os.replace(tmp, path)


def main():
   parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
   parser.add_argument("--cache", default=DEFAULT_CACHE)
   parser.add_argument("--delay", type=float, default=1.0,
                       help="seconds between requests (default 1.0)")
   parser.add_argument("--limit", type=int, default=0,
                       help="only process the first N entries (testing)")
   args = parser.parse_args()

   files_dir = os.path.join(args.cache, "files")
   os.makedirs(files_dir, exist_ok=True)
   fetcher = Fetcher(args.delay)

   body, _ = fetcher.request(DISPLAY_URL)
   display = parse_display_page(body.decode("utf-8", "replace"))
   write_json(os.path.join(args.cache, "display_names.json"), display)
   log("display page: %d headings" % len(display))

   entries, site_total = fetch_listing(fetcher)
   if args.limit:
      entries = entries[:args.limit]
   if site_total is not None and site_total != len(entries) and not args.limit:
      log("WARNING: site says %d entries, parsed %d" % (site_total,
                                                        len(entries)))

   manifest_path = os.path.join(args.cache, "manifest.json")
   prior = {}
   if os.path.isfile(manifest_path):
      with open(manifest_path, encoding="utf-8") as handle:
         for old in json.load(handle).get("entries", []):
            prior[old.get("slug")] = old
   taken = {}
   for number, entry in enumerate(entries, 1):
      if not entry["page_url"]:
         entry["status"] = "no-page-url"
         continue
      old = prior.get(entry["slug"])
      have_file = bool(old and old.get("file_name") and os.path.isfile(
         os.path.join(files_dir, old["file_name"])))
      if have_file:
         # Already downloaded on an earlier run: no request at all.
         for key in ("download_url", "file_name", "size", "sha256"):
            if key in old:
               entry[key] = old[key]
         entry["status"] = "cached"
         taken[entry["file_name"]] = entry["slug"]
         continue
      log("[%d/%d] %s" % (number, len(entries), entry["title"]))
      download_entry(fetcher, entry, files_dir, taken)
      if not entry["status"].startswith(("downloaded", "cached")):
         log("   FAILED: %s" % entry["status"])
      # Written after every entry so an interruption loses nothing.
      write_json(manifest_path, {"listing_url": LISTING_URL,
                                 "site_total": site_total,
                                 "entries": entries})

   write_json(manifest_path, {"listing_url": LISTING_URL,
                              "site_total": site_total, "entries": entries})
   tally = {}
   for entry in entries:
      key = entry["status"].split(" ")[0].rstrip(":")
      tally[key] = tally.get(key, 0) + 1
   log("done: %d entries; %s" % (len(entries), tally))
   return 0


if __name__ == "__main__":
   sys.exit(main())
