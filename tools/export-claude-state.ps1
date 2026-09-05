<#
.SYNOPSIS
   Bundle the Claude-side state for this project so it can be moved to another PC.

.DESCRIPTION
   THE REPO IS NOT THE PROBLEM -- that clones. What does NOT clone is everything
   Claude Code keeps outside git, and on 2026-09-04 NY4I asked for exactly this:
   "I don't need the repo files as I can pull those. I need your settings and
   memories and plans, etc."

   WHAT THIS COLLECTS

     memory\      108 files. The project's accumulated findings -- why the radio
                  factory is shaped as it is, which traps have already been paid
                  for, what NY4I has decided and why. This is the irreplaceable
                  part: it is not derivable from the source.
     plans\       Design plans written during earlier sessions. CLAUDE.md cites
                  one of them by path.
     skills\      Any project-relevant skill (graphify).
     CLAUDE.md    The GLOBAL instruction file -- coding standards, the 3-space
                  rule, the engineering bar. The repo's own CLAUDE.md clones;
                  this one does not.
     settings.json          Global Claude Code settings.
     settings.local.json    The clone's own gitignored settings.

   WHAT IT DELIBERATELY LEAVES

     The session transcripts (projects\<key>\*.jsonl) -- 346 MB here, and a
     record of conversations rather than of conclusions. The conclusions are in
     memory\. Pass -WithTranscripts if you want them anyway.

     Caches, image-cache, paste-cache, daemon state, file-history: machine
     state, not project state.

   THE ONE THING THAT SILENTLY BREAKS THE MOVE

     Claude Code keys a project's memory to the PROJECT PATH. This clone lives
     at C:\tr4w-d12, so the folder is `c--tr4w-d12`. Another machine holding the
     tree at, say, C:\projects\TR4W-D12 looks for `c--projects-TR4W-D12` and
     finds nothing -- no error, no warning, just a session that has forgotten
     everything.

     CLAUDE.md records that the clones ARE at different paths ("C:\tr4w-d12
     here, C:\projects\TR4W-D12 elsewhere"), so this is not hypothetical. The
     import script writes the folder name for the path it finds, and says so.

   .\tools\export-claude-state.ps1
   .\tools\export-claude-state.ps1 -Destination D:\move -WithTranscripts
#>

param(
   # Where to write the bundle.  Defaults beside the repo so it is easy to find.
   [string] $Destination = '',

   # Include the raw session transcripts.  Large, and rarely what is wanted --
   # see the note above.
   [switch] $WithTranscripts,

   # Produce a .zip as well as the folder.
   [switch] $Zip,

   # Override the computed memory-folder name, for a tree that has moved since
   # its memories were written.
   [string] $ProjectKey = ''
)

$ErrorActionPreference = 'Stop'

$repo      = Split-Path -Parent $PSScriptRoot
$claudeDir = Join-Path $env:USERPROFILE '.claude'
# THE KEY IS THE PATH WITH ITS SEPARATORS FLATTENED: C:\tr4w-d12 -> c--tr4w-d12.
# Derived, then VERIFIED against the folder that exists -- an approximate match
# here reads ANOTHER project's memories, which is worse than reading none.
# Measured 2026-09-04: a wrong key silently exported tr4w-i18n's four memories
# in place of this project's hundred and eight, and reported success.
$projectKey = ((Split-Path $repo -Qualifier).TrimEnd(':').ToLower()) + '--' +
              ((Split-Path $repo -NoQualifier).Trim('\').Replace('\', '-'))

if (-not $Destination)
   {
   # NOT beside the repo: this clone sits at C:\tr4w-d12, whose parent is the
   # drive ROOT, and Compress-Archive cannot write there.
   $Destination = Join-Path $env:USERPROFILE 'tr4w-claude-state'
   }

if (-not (Test-Path -LiteralPath $claudeDir))
   {
   Write-Output "export-claude-state: no $claudeDir on this machine -- nothing to export."
   exit 1
   }

if ($ProjectKey) { $projectKey = $ProjectKey }
$projectDir = Join-Path $claudeDir "projects\$projectKey"
if (-not (Test-Path -LiteralPath $projectDir))
   {
   # NO FUZZY FALLBACK.  It used to take the first project folder matching
   # '*tr4w*', and that is how this script collected the tr4w-i18n project's
   # memories instead of this one's -- reporting success while gathering the
   # wrong thing entirely.  A near miss on a key is not a match.
   Write-Output "export-claude-state: no memory folder for key '$projectKey'."
   Write-Output "  looked in $claudeDir\projects"
   Write-Output '  folders present:'
   Get-ChildItem (Join-Path $claudeDir 'projects') -Directory -ErrorAction SilentlyContinue |
      ForEach-Object { Write-Output "    $($_.Name)" }
   Write-Output ''
   Write-Output '  If one of those is this project under an older path, pass its name'
   Write-Output '  with -ProjectKey.'
   exit 1
   }

if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
New-Item -ItemType Directory -Path $Destination -Force | Out-Null

function Copy-Part
{
   param([string] $From, [string] $To, [string] $What)

   if (-not (Test-Path -LiteralPath $From))
      {
      Write-Output ("  {0,-22} -- absent, skipped" -f $What)
      return
      }
   $target = Join-Path $Destination $To
   New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
   Copy-Item -LiteralPath $From -Destination $target -Recurse -Force
   $n = if ((Get-Item $From).PSIsContainer) { (Get-ChildItem $From -Recurse -File).Count } else { 1 }
   Write-Output ("  {0,-22} {1} item(s)" -f $What, $n)
}

Write-Output "export-claude-state: project key '$projectKey'"
Write-Output "  from $claudeDir"
Write-Output "  to   $Destination"
Write-Output ''

Copy-Part (Join-Path $projectDir 'memory')        'memory'             'memory'
Copy-Part (Join-Path $claudeDir 'plans')          'plans'              'plans'
Copy-Part (Join-Path $claudeDir 'skills')         'skills'             'skills'
Copy-Part (Join-Path $claudeDir 'CLAUDE.md')      'CLAUDE.md'          'global CLAUDE.md'
Copy-Part (Join-Path $claudeDir 'settings.json')  'settings.json'      'global settings'
Copy-Part (Join-Path $repo '.claude\settings.local.json') 'settings.local.json' 'clone settings'

if ($WithTranscripts)
   {
   Copy-Part $projectDir 'transcripts' 'session transcripts'
   }

# The manifest travels WITH the bundle, because a folder of files whose
# destinations are not obvious is a folder nobody dares unpack.
$readme = @"
# Claude state for TR4W-D12

Exported $(Get-Date -Format 'yyyy-MM-dd HH:mm') from $env:COMPUTERNAME, repo at $repo.

Restore with import-claude-state.ps1 from the repo's tools\ folder, or by hand:

| this bundle          | goes to                                                    |
|----------------------|------------------------------------------------------------|
| memory\              | %USERPROFILE%\.claude\projects\<KEY>\memory\                |
| plans\               | %USERPROFILE%\.claude\plans\                                |
| skills\              | %USERPROFILE%\.claude\skills\                               |
| CLAUDE.md            | %USERPROFILE%\.claude\CLAUDE.md                             |
| settings.json        | %USERPROFILE%\.claude\settings.json                         |
| settings.local.json  | <repo>\.claude\settings.local.json                          |

## <KEY> is not a constant, and getting it wrong loses everything quietly

Claude Code keys a project's memory to the PROJECT PATH. This machine used

    $projectKey

because the repo is at $repo. If the new machine puts the tree somewhere else,
the key changes with it and the old folder is simply never read -- no error, no
warning, a session that has forgotten the project.

The repo's CLAUDE.md records that the clones really are at different paths
(C:\tr4w-d12 on one, C:\projects\TR4W-D12 on another), so check rather than
assume. import-claude-state.ps1 computes the key for the machine it runs on.

## What is NOT here

Session transcripts, unless you passed -WithTranscripts. They are large and they
record conversations; the conclusions drawn from them are in memory\.

Caches, image-cache, paste-cache, daemon state: machine state, not project state.

## What still has to be installed separately

The bundle carries no toolchain. tr4w\docs\BUILD.md has that recipe, and it is
ONE installer: lazarus-4.8-fpc-3.2.2-win32.exe (the 32-BIT build -- it carries
the i386 FPC, RTL and LCL together; a 64-bit Lazarus looks right and has none of
them).

Beyond it, this machine also had: Python 3 (the generators and two lints),
NSIS (only for -BuildInstaller), sqlite3 and objdump (diagnostics), and
rg/fd/sd/jq for convenience.
"@

Set-Content -LiteralPath (Join-Path $Destination 'README.md') -Value $readme -Encoding UTF8
Write-Output ''
Write-Output '  README.md              written'

if ($Zip)
   {
   $zipPath = "$Destination.zip"
   if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
   Compress-Archive -Path (Join-Path $Destination '*') -DestinationPath $zipPath
   Write-Output "  zipped -> $zipPath"
   }

Write-Output ''
Write-Output "export-claude-state: done.  Move $Destination to the other PC and run"
Write-Output "  tools\import-claude-state.ps1 -Source <that folder>"
