# Lint-NoSecrets.ps1 -- NOTHING SECRET IS TRACKED BY GIT.
#
# NY4I, 2026-09-12, while the credential store was being designed: "we also
# need to ensure the key is not in the repo."
#
# ------------------------------------------------------------------------
# WHY A LINT AND NOT A .gitignore RULE
# ------------------------------------------------------------------------
#
# .gitignore governs what git ADDS on its own. It does not stop `git add -f`,
# it does not apply to a file that was already tracked before the rule
# existed, and it says nothing about a secret pasted into a file that is
# tracked for other reasons -- a fixture, a document, a test.
#
# This asks the only question that matters: given what git is ACTUALLY
# tracking right now, is any of it a key or a protected value. A rule is a
# promise; this is a check.
#
# ------------------------------------------------------------------------
# WHAT IT LOOKS FOR
# ------------------------------------------------------------------------
#
#   1. A KEY FILE BY NAME. settings\tr4w.key and anything else ending .key.
#      The portable scheme writes one per installation and it is the whole
#      secret -- a committed key makes every protected value in that repo
#      readable by anyone who clones it.
#
#   2. A PROTECTED BLOB. The stored form names its own scheme, so a value
#      written by the cipher is recognisable on sight. One in a tracked file
#      means somebody committed their settings, and it also means the file
#      is useless to everybody else, since only their key opens it.
#
#   3. A PLAIN-TAGGED SECRET. `plain:` is what the store writes when no
#      protector would take the value. Tracked, it is a password in the
#      repository in the clear.
#
# ------------------------------------------------------------------------
# IT FAILS CLOSED
# ------------------------------------------------------------------------
#
# A guard that reports "0 found" while scanning nothing passes forever and
# tells you nothing -- the failure mode CLAUDE.md records for exactly this
# kind of check. So it asserts it scanned a plausible number of files and
# fails if git or the repository root cannot be read at all.

param(
   [string] $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'

# The scheme tags, spelled here rather than parsed out of the Pascal. A lint
# that derives its pattern from the code it checks agrees with that code by
# construction, including when the code is wrong.
$ProtectedTags = @('tr4w1:', 'wincred1:')
$PlainTag = 'plain:'

Push-Location $RepoRoot
try
{
   $tracked = @(git ls-files)
   if ($LASTEXITCODE -ne 0)
   {
      Write-Error "Lint-NoSecrets: could not list tracked files -- is this a git repository?"
      exit 1
   }

   # THE FLOOR. This tree has thousands of tracked files; a handful means the
   # listing failed in a way that did not set an exit code, and a pass on
   # that basis is worth nothing.
   if ($tracked.Count -lt 100)
   {
      Write-Error ("Lint-NoSecrets: only $($tracked.Count) tracked file(s) " +
                   "found -- refusing to report a pass on a listing this small.")
      exit 1
   }

   $failures = New-Object System.Collections.Generic.List[string]

   # ---- 1. key files, by name -------------------------------------------
   foreach ($path in $tracked)
   {
      if ($path -match '\.key$')
      {
         $failures.Add("TRACKED KEY FILE: $path")
      }
   }

   # ---- 2 and 3. protected or plain-tagged values, by content -----------
   #
   # TEXT FILES ONLY, and by extension rather than by sniffing: a .trw log or
   # a .dta database can contain any byte sequence, and reading all of them
   # to look for a five-character tag would be slow and would false-positive
   # on binary noise.
   $textLike = @('.json', '.ini', '.cfg', '.pas', '.lpr', '.inc', '.md',
                 '.txt', '.ps1', '.sh', '.py', '.xml', '.lfm', '.adi',
                 '.cbr', '.yml', '.yaml')

   $scanned = 0
   foreach ($path in $tracked)
   {
      # A REGEX, NOT [System.IO.Path]. git ls-files QUOTES a path holding
      # unusual bytes -- this tree has one, a .dom file whose name carries an
      # escaped control character -- and the Path API throws on it. The
      # extension is the tail after the last dot and needs no path parser.
      $ext = ''
      if ($path -match '(\.[A-Za-z0-9]+)"?$')
      {
         $ext = $Matches[1].ToLowerInvariant()
      }
      if ($textLike -notcontains $ext)
      {
         continue
      }
      if (-not (Test-Path -LiteralPath $path))
      {
         continue
      }

      $scanned++
      $text = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue
      if ($null -eq $text)
      {
         continue
      }

      foreach ($tag in $ProtectedTags)
      {
         # THE LINT AND THE STORE BOTH LIVE IN THIS REPOSITORY, so the tag
         # appears in the Pascal that defines it and in the tests that pin
         # it. Those are declarations of the format, not secrets, and the
         # check skips the files whose job is to name it.
         if ($text.Contains($tag) -and
             ($path -notlike '*uSecretStore*') -and
             ($path -notlike '*uTestSecretStore*') -and
             ($path -notlike '*Lint-NoSecrets*'))
         {
            $failures.Add("PROTECTED VALUE in a tracked file: $path (tag '$tag')")
         }
      }

      # The plain tag only counts inside a settings file, because the word
      # is ordinary English everywhere else.
      if (($ext -eq '.json') -and $text.Contains('"' + $PlainTag))
      {
         $failures.Add("UNPROTECTED SECRET in a tracked settings file: $path")
      }
   }

   if ($scanned -lt 50)
   {
      Write-Error ("Lint-NoSecrets: only $scanned text file(s) scanned -- " +
                   "the filter is wrong, not the repository.")
      exit 1
   }

   if ($failures.Count -gt 0)
   {
      Write-Host ''
      Write-Host 'Lint-NoSecrets FAILED' -ForegroundColor Red
      foreach ($f in $failures)
      {
         Write-Host ("   " + $f) -ForegroundColor Red
      }
      Write-Host ''
      Write-Host '   A key opens every protected value written with it, so a' -ForegroundColor Yellow
      Write-Host '   committed key is worse than no protection at all.' -ForegroundColor Yellow
      Write-Host '   Remove the file from git (git rm --cached <path>), then' -ForegroundColor Yellow
      Write-Host '   TREAT THE SECRET AS DISCLOSED and change it.' -ForegroundColor Yellow
      exit 1
   }

   Write-Host ("   Lint-NoSecrets: $($tracked.Count) tracked file(s), " +
               "$scanned scanned for content -- no key file, no stored secret.")
}
finally
{
   Pop-Location
}
