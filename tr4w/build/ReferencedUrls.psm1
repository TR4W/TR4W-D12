# ReferencedUrls -- the ONE definition of what a "referenced URL" is and how
# tr4w\build\referenced-urls.txt is read. Lint-ReferencedUrls.ps1 (offline, gates
# the build) and Check-ReferencedUrls.ps1 (network, a manual pre-release step)
# both import it, so the extractor and the parser cannot drift apart.
#
# THE DATA FILE, one entry per line, fields separated by a pipe:
#
#    url | kind | probe | owner | arg | allow
#
#    kind   endpoint   a server the PROGRAM contacts (download, upload, post, API)
#           link       a page the program OPENS in the operator's browser
#           tooling    fetched by a build script or a tools\ program, not the app
#           doc        a URL in a comment or a note; probed only with -IncludeDocs
#           template   a URL with a placeholder (%d, $ARCH); `arg` is a sample
#           namespace  an XML namespace or DTD identifier -- never fetched
#           license    a licence header -- never fetched
#    probe  head    HEAD, falling back to a body-less GET
#           get     a body-less GET (the server refuses HEAD)
#           root    the host root: the real URL is POST-only, so only the host
#                   is asked, and nothing is ever posted
#           sample  probe the URL in `arg` (a template with a placeholder filled)
#           skip    DELIBERATELY not probed; `arg` is the reason (required)
#           none    not a probe subject (namespace, license)
#    owner  the unit or script that carries it
#    arg    see sample / skip
#    allow  comma list of hosts a redirect may land on without being a failure
#           (a CDN a release download legitimately hands off to)
#
# Lines starting with # and blank lines are ignored.

$script:Kinds  = @('endpoint', 'link', 'tooling', 'doc', 'template', 'namespace', 'license')
$script:Probes = @('head', 'get', 'root', 'sample', 'skip', 'none')

# scheme, a dotted host (so "http://..." and "https://host/path" are not
# URLs), optional port, optional path. The path class stops at whitespace,
# quotes, angle brackets and a backtick; trailing punctuation is trimmed below.
$script:UrlPattern = [regex] ('(?i)https?://[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+(?::[0-9]+)?' +
                              '(?:[/?#][^\s''"<>`]*)?')

function ConvertTo-CanonicalUrl
{
   param([string] $Url)

   # A PowerShell subexpression is code, not part of the address.
   $cut = $Url.IndexOf('$(')
   if ($cut -ge 0)
      {
      $Url = $Url.Substring(0, $cut)
      }
   # Prose punctuation, a closing brace of a brace comment, a bare '?'.
   return $Url.TrimEnd('.', ',', ';', ':', ')', ']', '}', '''', '?', '!')
}

function Find-UrlLiteralsInText
{
   param([string] $Text)

   $seen = New-Object System.Collections.ArrayList
   foreach ($m in $script:UrlPattern.Matches($Text))
      {
      $u = ConvertTo-CanonicalUrl $m.Value
      if (($u -match '^https?://[^/]+/?$') -or ($u.Length -gt 10))
         {
         if (-not $seen.Contains($u))
            {
            [void] $seen.Add($u)
            }
         }
      }
   return @($seen)
}

function Get-UrlHost
{
   param([string] $Url)
   return ([uri] $Url).Host.ToLowerInvariant()
}

# Returns the entries, or throws on a malformed line: a table that cannot be
# read must fail the lint, never read as empty.
function Read-UrlTable
{
   param([string] $Path)

   if (-not (Test-Path -LiteralPath $Path))
      {
      throw "table not found: $Path"
      }
   $entries = New-Object System.Collections.ArrayList
   $n = 0
   foreach ($raw in [IO.File]::ReadAllLines($Path))
      {
      $n++
      $line = $raw.Trim()
      if (($line -eq '') -or $line.StartsWith('#'))
         {
         continue
         }
      $f = @($line.Split('|') | ForEach-Object { $_.Trim() })
      if (($f.Count -lt 4) -or ($f.Count -gt 6))
         {
         throw ("{0}:{1}: expected 4 to 6 pipe-separated fields, found {2}" -f $Path, $n, $f.Count)
         }
      while ($f.Count -lt 6)
         {
         $f += ''
         }
      [void] $entries.Add([pscustomobject] @{
         Url = $f[0]; Kind = $f[1]; Probe = $f[2]; Owner = $f[3]
         Arg = $f[4]; Allow = $f[5]; Line = $n })
      }
   return @($entries)
}

# Rules a table must satisfy by itself; returns a list of error strings.
function Test-UrlTableRules
{
   param($Entries)

   $errs = New-Object System.Collections.ArrayList
   $seen = @{}
   foreach ($e in $Entries)
      {
      $where = "line $($e.Line) ($($e.Url))"
      if ($seen.ContainsKey($e.Url))
         {
         [void] $errs.Add("$where : listed twice (first at line $($seen[$e.Url]))")
         }
      $seen[$e.Url] = $e.Line
      if ($e.Url -notmatch '^https?://[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+')
         {
         [void] $errs.Add("$where : not an absolute http(s) URL")
         continue
         }
      if ($script:Kinds -notcontains $e.Kind)
         {
         [void] $errs.Add("$where : unknown kind '$($e.Kind)'")
         }
      if ($script:Probes -notcontains $e.Probe)
         {
         [void] $errs.Add("$where : unknown probe '$($e.Probe)'")
         }
      if ($e.Owner -eq '')
         {
         [void] $errs.Add("$where : no owner")
         }
      if (($e.Probe -eq 'skip') -and ($e.Arg -eq ''))
         {
         [void] $errs.Add("$where : probe 'skip' needs its reason in the fifth field")
         }
      if (($e.Probe -eq 'sample') -and ($e.Arg -notmatch '^https?://'))
         {
         [void] $errs.Add("$where : probe 'sample' needs a URL in the fifth field")
         }
      if ((@('endpoint', 'link', 'tooling') -contains $e.Kind) -and ($e.Probe -eq 'none'))
         {
         [void] $errs.Add("$where : a $($e.Kind) must be probed or explicitly skipped, not 'none'")
         }
      # THE RULE THAT HAS A REASON (call-history download rules): this host is
      # never contacted by a check, whatever the table says elsewhere.
      if (($e.Url -match '^https?://([^/]*\.)?supercheckhistory\.com') -and ($e.Probe -ne 'skip'))
         {
         [void] $errs.Add("$where : supercheckhistory.com must be probe 'skip' -- never contacted by a check")
         }
      # THE WA7BNM CONTEST CALENDAR (contestcalendar.com, and hornucopia.com/contestcal, its
      # older address): its Terms of Use forbid "any software robot, spider or other automated
      # means to access, monitor or copy the content of the Site" without the owner's written
      # authorization. A check is such a robot, so these are never probed (issue 248, 2026-11-09).
      if (($e.Url -match '^https?://([^/]*\.)?(contestcalendar\.com|hornucopia\.com/contestcal)') -and ($e.Probe -ne 'skip'))
         {
         [void] $errs.Add("$where : the WA7BNM Contest Calendar must be probe 'skip' -- its terms forbid automated access")
         }
      }
   return @($errs)
}

Export-ModuleMember -Function ConvertTo-CanonicalUrl, Find-UrlLiteralsInText, Get-UrlHost,
                              Read-UrlTable, Test-UrlTableRules
