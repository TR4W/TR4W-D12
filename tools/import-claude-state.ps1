<#
.SYNOPSIS
   Restore the Claude-side state exported by export-claude-state.ps1.

.DESCRIPTION
   Run this on the NEW machine, after cloning the repo, with the bundle folder.

   IT COMPUTES THE MEMORY KEY FOR *THIS* MACHINE, which is the whole reason this
   script exists rather than a copy-paste instruction. Claude Code keys a
   project's memory to the PROJECT PATH: a tree at C:\tr4w-d12 stores under
   `c--tr4w-d12`, and the same tree at C:\projects\TR4W-D12 stores under
   `c--projects-TR4W-D12`. Copy the folder across unchanged and the new session
   reads nothing -- silently, because an absent memory folder is indistinguish-
   able from a project that has never been worked on.

   NOTHING IS OVERWRITTEN WITHOUT SAYING SO. CLAUDE.md and settings.json are
   personal files that may already exist and differ; each is backed up beside
   itself before being replaced, and the backup is named.

   .\tools\import-claude-state.ps1 -Source D:\move\tr4w-claude-state
   .\tools\import-claude-state.ps1 -Source D:\move\tr4w-claude-state -WhatIfOnly
#>

param(
   [Parameter(Mandatory = $true)]
   [string] $Source,

   # Report what would happen and change nothing.
   [switch] $WhatIfOnly
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Source))
   {
   Write-Output "import-claude-state: no bundle at $Source"
   exit 1
   }

$repo      = Split-Path -Parent $PSScriptRoot
$claudeDir = Join-Path $env:USERPROFILE '.claude'

# THE KEY, FOR THIS MACHINE.  C:\tr4w-d12 -> c--tr4w-d12
# THE KEY IS THE PATH WITH ITS SEPARATORS FLATTENED: C:\tr4w-d12 -> c--tr4w-d12.
# Derived, then VERIFIED against the folder that exists -- an approximate match
# here reads ANOTHER project's memories, which is worse than reading none.
# Measured 2026-09-04: a wrong key silently exported tr4w-i18n's four memories
# in place of this project's hundred and eight, and reported success.
$projectKey = ((Split-Path $repo -Qualifier).TrimEnd(':').ToLower()) + '--' +
              ((Split-Path $repo -NoQualifier).Trim('\').Replace('\', '-'))

$memoryTarget = Join-Path $claudeDir "projects\$projectKey\memory"

Write-Output "import-claude-state:"
Write-Output "  repo        $repo"
Write-Output "  project key $projectKey"
Write-Output "  memory ->   $memoryTarget"
Write-Output ''

$plan = @(
   @{ From = 'memory';             To = $memoryTarget;                                  What = 'memory'          }
   @{ From = 'plans';              To = (Join-Path $claudeDir 'plans');                 What = 'plans'           }
   @{ From = 'skills';             To = (Join-Path $claudeDir 'skills');                What = 'skills'          }
   @{ From = 'CLAUDE.md';          To = (Join-Path $claudeDir 'CLAUDE.md');             What = 'global CLAUDE.md'}
   @{ From = 'settings.json';      To = (Join-Path $claudeDir 'settings.json');         What = 'global settings' }
   @{ From = 'settings.local.json';To = (Join-Path $repo '.claude\settings.local.json');What = 'clone settings'  }
)

foreach ($step in $plan)
   {
   $from = Join-Path $Source $step.From
   if (-not (Test-Path -LiteralPath $from))
      {
      Write-Output ("  {0,-18} not in the bundle, skipped" -f $step.What)
      continue
      }

   $to = $step.To
   $exists = Test-Path -LiteralPath $to

   if ($WhatIfOnly)
      {
      Write-Output ("  {0,-18} would {1} {2}" -f $step.What, $(if ($exists) { 'REPLACE' } else { 'create ' }), $to)
      continue
      }

   if ($exists)
      {
      # BACKED UP, NOT CLOBBERED.  These are personal files and the machine may
      # already have its own; losing them to an import is not recoverable.
      $backup = "$to.before-import-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
      Move-Item -LiteralPath $to -Destination $backup -Force
      Write-Output ("  {0,-18} existing kept as {1}" -f $step.What, (Split-Path $backup -Leaf))
      }

   New-Item -ItemType Directory -Path (Split-Path $to -Parent) -Force | Out-Null
   Copy-Item -LiteralPath $from -Destination $to -Recurse -Force
   Write-Output ("  {0,-18} restored" -f $step.What)
   }

if ($WhatIfOnly)
   {
   Write-Output ''
   Write-Output 'import-claude-state: nothing changed (-WhatIfOnly).'
   exit 0
   }

Write-Output ''
Write-Output 'import-claude-state: done.'
Write-Output ''
Write-Output 'Check it took: start Claude Code in the repo and ask it something only the'
Write-Output 'memories know -- "why is BandChangeArray at unit level?" or "what does'
Write-Output 'a fresh clone not give me?".  A session that cannot answer has not found'
Write-Output "the memory folder, and the likeliest reason is that this clone's path"
Write-Output 'differs from the one the bundle came from.'
