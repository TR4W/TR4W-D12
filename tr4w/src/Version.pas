// This file is part of TR4W  (SRC)
{
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 }
unit version;
{$I tr4w.inc}
interface
const
  TR4W_CURRENTVERSION_NUMBER            = '5.0.45';

  TR4W_CURRENTVERSION                   = 'TR4W v.' + TR4W_CURRENTVERSION_NUMBER;

  TR4W_CURRENTVERSIONDATE               = 'November, 2026' ;

  TR4WSERVER_CURRENTVERSION             = '1.41';

  (* THE PROJECT'S WEBSITE -- the ONE spelling of it (2026-11-20). Every
    address on the site is built from it: the About box's link, Help > Home
    Page, the download page (VC.TR4W_DOWNLOAD_LINK), the version check
    (uCheckLatestVersion.VERSION_URL), the TRMASTER.DTA download
    (uTRMasterUpdate.TRMASTER_DOWNLOAD_URL) and the credit line the 3830 and
    summary-sheet reports print (PostUnit.SoftwareCredit). It lives here, with
    the version, because it is the product's identity and this unit is a
    leaf every one of those already uses or can use without pulling in VC.
    No trailing slash: a caller adds the path. Pinned by uTestTR4WWebsite. *)
  TR4W_WEBSITE                          = 'https://tr4w.net';

  (* THE PROJECT'S DATA HOST on GitHub Pages (NY4I, 2026-11-20): the big files
    the program downloads when the operator asks. Today that is the callsign
    lookup database (FCC and ISED licensees), which tools\trmaster\lookup_build.py
    publishes as fcc_lookup.sqlite.gz (gzip of one SQLite file; the download
    gunzips it) beside a ~600 byte manifest.json to fetch first
    (tools\trmaster\LOOKUP_DB.md has the client flow). The URLs are built here,
    from the host and the file NAMES, so changing either is one line. The
    download itself is not written yet (issue 337; the setup wizard's
    external-files page will call it). No trailing slash on the host. *)
  TR4W_DATA_SITE                        = 'https://tr4w.github.io';
  FCC_LICENSE_FILE_NAME                 = 'fcc_lookup.sqlite.gz';
  FCC_LICENSE_MANIFEST_NAME             = 'manifest.json';
  FCC_LICENSE_DOWNLOAD_URL              = TR4W_DATA_SITE + '/' + FCC_LICENSE_FILE_NAME;
  FCC_LICENSE_MANIFEST_URL              = TR4W_DATA_SITE + '/' + FCC_LICENSE_MANIFEST_NAME;

 implementation
 end.

