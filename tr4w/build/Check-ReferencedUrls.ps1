<#
.SYNOPSIS
   Pre-release check (issue 248): does every URL TR4W references still answer
   validly, and does it still answer from where we expect?

.DESCRIPTION
   READ-ONLY, ALWAYS. HEAD (a body-less GET where a server refuses HEAD); no
   credentials, no cookies, no request body, never a POST. A URL the program
   POSTS to (score post, SCP upload, HamScore, Club Log, WRL) is probed by asking
   the HOST ROOT instead -- nothing is ever sent to the real path, so no QSO and
   no score can leave this script. supercheckhistory.com is never contacted
   (call-history download rules): its row is `skip` and this script refuses to
   probe it even if the table said otherwise.

   WHAT IS PROBED comes from build\referenced-urls.txt (format in
   ReferencedUrls.psm1), which Lint-ReferencedUrls.ps1 keeps equal to the tree.
   Endpoint, link and tooling rows by default; documentation links in comments
   only with -IncludeDocs.

   THE REPORT SEPARATES FOUR THINGS, because they need different responses:

     OK                 answered 2xx, from the host we asked (or an allowed one)
     REACHABLE          401/403/405: alive, but refuses an anonymous or this-method
                        request. Expected for POST-only and credentialed APIs; a
                        warning, not a failure. (A bot wall also looks like this.)
     UNREACHABLE        no answer: DNS, connect, TLS or timeout. FAILS.
     ERROR              the host answered with 4xx/5xx other than the above. FAILS.
     REDIRECTED         the final host is not the one asked (www. ignored) and not
                        in the row's allow list. FAILS.
     INSECURE-REDIRECT  a hop from https to http. FAILS.

   A TRANSIENT FAILURE IS RETRIED ONCE (-Retries, default 1, after a short pause)
   before it is reported: UNREACHABLE and a 5xx are both retried. A redirect or a
   404 is an answer and is not retried.

   Exit code = the number of failures. NOT in Run-Lints and NOT in the ordinary
   build: a remote site being briefly down must not stop a build. It runs from
   FullBuild.ps1 -CheckUrls, and from a release workflow step.

   .\Check-ReferencedUrls.ps1                   # endpoints, links, tooling
   .\Check-ReferencedUrls.ps1 -IncludeDocs      # + documentation links
   .\Check-ReferencedUrls.ps1 -Only 'tr4w\.net' # rows whose URL matches
#>
param(
   [string] $Table = (Join-Path $PSScriptRoot 'referenced-urls.txt'),
   [switch] $IncludeDocs,
   [string] $Only = '',
   [int]    $TimeoutSec = 20,
   [int]    $Retries = 1
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ReferencedUrls.psm1') -Force

Add-Type -AssemblyName System.Net.Http
try
   {
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   }
catch
   {
   }

$handler = New-Object System.Net.Http.HttpClientHandler
$handler.AllowAutoRedirect = $false          # hops are followed by hand so each one is judged
$handler.UseCookies = $false
$client = New-Object System.Net.Http.HttpClient($handler)
$client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
$client.DefaultRequestHeaders.UserAgent.ParseAdd('TR4W-referenced-url-check/1.0 (read-only; HEAD/GET)')

function Get-InnerMessage
{
   param($Exception)
   $e = $Exception
   while ($e.InnerException)
      {
      $e = $e.InnerException
      }
   if ($e -is [System.Threading.Tasks.TaskCanceledException])
      {
      return "timed out after ${TimeoutSec}s"
      }
   return $e.Message
}

# One request, no redirects followed. Returns the response (caller disposes).
function Send-One
{
   param([string] $Method, [string] $Url)
   $req = New-Object System.Net.Http.HttpRequestMessage((New-Object System.Net.Http.HttpMethod($Method.ToUpper())), $Url)
   try
      {
      return $client.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
      }
   finally
      {
      $req.Dispose()
      }
}

function Test-SameHost
{
   param([string] $A, [string] $B, [string] $Allow)
   $ha = (Get-UrlHost $A) -replace '^www\.', ''
   $hb = (Get-UrlHost $B) -replace '^www\.', ''
   if ($ha -eq $hb)
      {
      return $true
      }
   foreach ($a in ($Allow -split ',' | Where-Object { $_ -ne '' }))
      {
      $a = $a.Trim().ToLowerInvariant()
      if (($hb -eq $a) -or $hb.EndsWith('.' + $a))
         {
         return $true
         }
      }
   return $false
}

# ONE attempt: follow up to 8 hops, return a result object.
function Invoke-Attempt
{
   param([string] $Url, [string] $FirstMethod)

   $cur = $Url
   $method = $FirstMethod
   $hops = New-Object System.Collections.ArrayList
   for ($i = 0; $i -lt 9; $i++)
      {
      try
         {
         $resp = Send-One $method $cur
         # A server that refuses HEAD: ask again with a body-less GET.
         if (($method -eq 'Head') -and (@(400, 403, 405, 501) -contains [int] $resp.StatusCode))
            {
            $resp.Dispose()
            $method = 'Get'
            $resp = Send-One $method $cur
            }
         }
      catch
         {
         return [pscustomobject] @{ Kind = 'unreachable'; Status = 0; Final = $cur; Hops = $hops
                                    Note = (Get-InnerMessage $_.Exception) }
         }
      $code = [int] $resp.StatusCode
      $loc = $resp.Headers.Location
      $resp.Dispose()
      if (($code -ge 300) -and ($code -lt 400) -and $loc)
         {
         $next = (New-Object System.Uri((New-Object System.Uri($cur)), $loc)).AbsoluteUri
         [void] $hops.Add($next)
         $cur = $next
         continue
         }
      return [pscustomobject] @{ Kind = 'answered'; Status = $code; Final = $cur; Hops = $hops; Note = '' }
      }
   return [pscustomobject] @{ Kind = 'unreachable'; Status = 0; Final = $cur; Hops = $hops
                              Note = 'more than 8 redirects' }
}

# Probe with the single retry, then judge.
function Invoke-Probe
{
   param($Entry, [string] $Target, [string] $FirstMethod)

   $r = $null
   for ($try = 0; $try -le $Retries; $try++)
      {
      $r = Invoke-Attempt $Target $FirstMethod
      $transient = ($r.Kind -eq 'unreachable') -or (($r.Kind -eq 'answered') -and ($r.Status -ge 500))
      if (-not $transient)
         {
         break
         }
      if ($try -lt $Retries)
         {
         Start-Sleep -Seconds 3
         }
      }

   $result = 'OK'
   $note = $r.Note
   if ($r.Kind -eq 'unreachable')
      {
      $result = 'UNREACHABLE'
      }
   else
      {
      # Redirect judgement first: where did it end up?
      $prev = $Target
      $insecure = $false
      foreach ($h in $r.Hops)
         {
         if (($prev -like 'https://*') -and ($h -like 'http://*'))
            {
            $insecure = $true
            }
         $prev = $h
         }
      if ($insecure)
         {
         $result = 'INSECURE-REDIRECT'
         }
      elseif (-not (Test-SameHost $Target $r.Final $Entry.Allow))
         {
         $result = 'REDIRECTED'
         }
      elseif (($r.Status -ge 200) -and ($r.Status -lt 300))
         {
         $result = 'OK'
         }
      elseif (@(401, 403, 405) -contains $r.Status)
         {
         $result = 'REACHABLE'
         $note = 'refuses an anonymous / this-method request'
         }
      else
         {
         $result = 'ERROR'
         }
      }
   if (($r.Final -ne $Target) -and ($result -ne 'UNREACHABLE'))
      {
      $note = ("-> {0} {1}" -f $r.Final, $note).Trim()
      }
   return [pscustomobject] @{ Result = $result; Status = $r.Status; Note = $note }
}

try
   {
   $entries = @(Read-UrlTable $Table)
   }
catch
   {
   Write-Host "Check-ReferencedUrls: $($_.Exception.Message)" -ForegroundColor Red
   exit 1
   }
$rules = @(Test-UrlTableRules $entries)
if ($rules.Count -gt 0)
   {
   $rules | ForEach-Object { Write-Host "  table: $_" -ForegroundColor Red }
   exit 1
   }

$rows = New-Object System.Collections.ArrayList
$failures = 0
foreach ($e in $entries)
   {
   if (($e.Kind -eq 'doc') -and (-not $IncludeDocs))
      {
      continue
      }
   if (($Only -ne '') -and ($e.Url -notmatch $Only))
      {
      continue
      }
   if ($e.Probe -eq 'none')
      {
      continue
      }
   # BELT AND BRACES: the never-contact host is refused here too, not only in the lint.
   if (($e.Probe -eq 'skip') -or ($e.Url -match 'supercheckhistory\.com') -or
       ($e.Url -match '^https?://([^/]*\.)?(contestcalendar\.com|hornucopia\.com/contestcal)'))
      {
      $why = $e.Arg
      if ($why -eq '')
         {
         $why = 'never contacted'
         }
      [void] $rows.Add([pscustomobject] @{ Result = 'not probed'; Status = ''; Kind = $e.Kind; Url = $e.Url; Note = $why })
      continue
      }

   $target = $e.Url
   $first = 'Head'
   if ($e.Probe -eq 'get')
      {
      $first = 'Get'
      }
   elseif ($e.Probe -eq 'root')
      {
      $u = New-Object System.Uri($e.Url)
      $target = '{0}://{1}/' -f $u.Scheme, $u.Authority
      }
   elseif ($e.Probe -eq 'sample')
      {
      $target = $e.Arg
      }

   $p = Invoke-Probe $e $target $first
   if (@('UNREACHABLE', 'ERROR', 'REDIRECTED', 'INSECURE-REDIRECT') -contains $p.Result)
      {
      $failures++
      }
   $note = $p.Note
   if ($target -ne $e.Url)
      {
      $note = ("asked {0}  {1}" -f $target, $note).Trim()
      }
   [void] $rows.Add([pscustomobject] @{ Result = $p.Result; Status = $p.Status; Kind = $e.Kind; Url = $e.Url; Note = $note })
   }

foreach ($r in $rows)
   {
   $colour = 'Green'
   if (@('UNREACHABLE', 'ERROR', 'REDIRECTED', 'INSECURE-REDIRECT') -contains $r.Result)
      {
      $colour = 'Red'
      }
   elseif (@('REACHABLE', 'not probed') -contains $r.Result)
      {
      $colour = 'Yellow'
      }
   Write-Host ("{0,-17} {1,-4} {2,-8} {3}" -f $r.Result, $r.Status, $r.Kind, $r.Url) -ForegroundColor $colour
   if ($r.Note -ne '')
      {
      Write-Host ("{0,31}{1}" -f '', $r.Note) -ForegroundColor DarkGray
      }
   }

Write-Host ''
$rows | Group-Object Result | Sort-Object Name | ForEach-Object { Write-Host ("  {0,-17} {1}" -f $_.Name, $_.Count) }
if ($rows.Count -eq 0)
   {
   Write-Host 'Check-ReferencedUrls: nothing was probed -- refusing to report a pass.' -ForegroundColor Red
   exit 1
   }
if ($failures -gt 0)
   {
   Write-Host ("Check-ReferencedUrls: {0} URL(s) dead, in error or redirected elsewhere." -f $failures) -ForegroundColor Red
   }
else
   {
   Write-Host 'Check-ReferencedUrls: no failures.' -ForegroundColor Green
   }
$client.Dispose()
exit $failures
