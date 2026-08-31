# Lint-SearchIndex -- every editable control on a Preferences section panel must
# be reachable, both by the operator's search box and by the code that saves it.
#
# WHY THIS EXISTS. The Preferences search index is built from three sources and a
# setting reaches it through exactly one of them:
#
#   1. FBindings          -- registered settings, indexed automatically. This is
#                            the only path that cannot be forgotten.
#   2. AddHandWiredToSearchIndex(command, control)  -- a hand-maintained list.
#   3. AddStoreBackedToSearchIndex(control)         -- for a control with no
#                            CFGCA command behind it, only a store property.
#
# Two of those three are hand-maintained, so a control added in the designer and
# then not registered is INVISIBLE to search while looking perfectly normal on
# screen. That is not hypothetical: searching Preferences for "TCI" returned
# nothing while "Enable the TCI Server" sat plainly on the TCI Server page
# (NY4I, 2026-08-30), because a store-backed control had no route into the index
# at all. The route now exists; nothing checked that anyone used it.
#
# WHAT IT CHECKS. Walk uPrefsForm.lfm for every TCheckBox / TEdit / TComboBox
# inside a section panel -- a direct child of layContent, which is precisely how
# SectionPanelFor decides at run time -- and fail if the control's name appears
# in none of Bind(), AddHandWiredToSearchIndex() or AddStoreBackedToSearchIndex()
# in uPrefsForm.pas.
#
# WHAT IT DELIBERATELY DOES NOT CHECK, so nobody reads more into a pass than is
# there:
#
#   - GENERATED controls. The per-prefix section panels are built in code from
#     the settings registry, so they cannot be in the .lfm and are already
#     covered automatically by source 1. This lint is about DESIGNED controls,
#     which are the ones a person adds by hand and can forget.
#   - Whether the registration is CORRECT. A control bound to the wrong key
#     passes here. Lint-SettingsMigration is what checks a key's three halves
#     agree.
#
# It is a BLOCKING lint, unlike the pascal-glob hook's warning, because the
# failure it catches is silent in every other way: nothing warns, nothing throws,
# the setting simply does nothing or cannot be found.

[CmdletBinding()]
param(
   [string] $SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'src')
)

$ErrorActionPreference = 'Stop'

$lfm = Join-Path $SourceDir 'ui\lcl\uPrefsForm.lfm'
$pas = Join-Path $SourceDir 'ui\lcl\uPrefsForm.pas'

foreach ($f in @($lfm, $pas))
{
   if (-not (Test-Path $f))
   {
      Write-Host "  Lint-SearchIndex: FAILED -- missing $f" -ForegroundColor Red
      exit 1
   }
}

# ---------------------------------------------------------------------------
# The designed controls, by section panel.
#
# The .lfm is indentation-structured, so the panel a control belongs to is the
# nearest enclosing object at the section-panel depth. That is the same question
# SectionPanelFor answers by walking Parent links.
# ---------------------------------------------------------------------------

$lines = Get-Content -LiteralPath $lfm
$INTERESTING = '^(TCheckBox|TEdit|TComboBox)$'

$inContent   = $false
$contentInd  = -1
$panelInd    = -1
$currentPanel = ''
$controls    = @()

foreach ($line in $lines)
{
   if ($line -notmatch '^(\s*)object\s+(\w+):\s*(\w+)\s*$')
   {
      continue
   }
   $indent = $Matches[1].Length
   $name   = $Matches[2]
   $type   = $Matches[3]

   if ($name -eq 'layContent')
   {
      $inContent  = $true
      $contentInd = $indent
      $panelInd   = $indent + 2
      continue
   }
   if (-not $inContent) { continue }

   # Back out to or above layContent's own level: the content panel is finished.
   if ($indent -le $contentInd)
   {
      $inContent = $false
      continue
   }

   if ($indent -eq $panelInd)
   {
      # A direct child of layContent IS a section panel (TLabel placeholders
      # included -- they carry no controls, so they simply contribute none).
      $currentPanel = $name
      continue
   }

   if ($type -match $INTERESTING -and $currentPanel -ne '')
   {
      $controls += [pscustomobject]@{ Name = $name; Type = $type; Panel = $currentPanel }
   }
}

if ($controls.Count -eq 0)
{
   # FAILS CLOSED. A parser that silently matches nothing would report a clean
   # pass forever -- the exact shape of guard this tree has been bitten by.
   Write-Host "  Lint-SearchIndex: FAILED -- parsed 0 controls from uPrefsForm.lfm; the parser is broken, not the form." -ForegroundColor Red
   exit 1
}

# ---------------------------------------------------------------------------
# Which of them are registered.
# ---------------------------------------------------------------------------

$src = Get-Content -LiteralPath $pas -Raw

$registered = @{}
foreach ($pattern in @(
   'Bind\(\s*(\w+)\s*,',
   'AddHandWiredToSearchIndex\(\s*\w+\s*,\s*''[^'']*''\s*,\s*(\w+)\s*\)',
   'AddStoreBackedToSearchIndex\(\s*\w+\s*,\s*(\w+)\s*[,)]'))
{
   foreach ($m in [regex]::Matches($src, $pattern))
   {
      $registered[$m.Groups[1].Value] = $true
   }
}

if ($registered.Count -eq 0)
{
   Write-Host "  Lint-SearchIndex: FAILED -- found 0 registrations in uPrefsForm.pas; the patterns are broken, not the form." -ForegroundColor Red
   exit 1
}

# ---------------------------------------------------------------------------
# CONTROLS THAT ARE NOT SETTINGS, and must stay out of the settings search.
#
# Several pages are RECORD EDITORS, not setting pages: the fields edit the item
# currently selected in a list -- a cluster definition, a rotator, a station
# profile, a UDP destination. "Cluster name" is a property of one cluster among
# many, not a preference, so indexing it would put an answer in the search
# results that changes meaning depending on which row happens to be selected.
#
# They are listed by name rather than by page because a page can hold both: the
# Cluster page carries the editor fields AND real settings.
#
# ADDING A NAME HERE IS A CLAIM, not a way to quiet the lint. The claim is that
# the control edits a member of a collection. If it turns out to be a genuine
# setting, register it instead -- an entry here makes it permanently unfindable.
$NOT_A_SETTING = @(
   # the cluster definition being edited in lstClusters
   'cbxClusterServer', 'edtClusterCommand', 'edtClusterLogin', 'edtClusterName',
   'edtClusterPassword',
   # the rotator being edited in lstRotators
   'cbxRotatorPort', 'cbxRotatorType', 'edtRotatorBands', 'edtRotatorBaud',
   'edtRotatorIP', 'edtRotatorName', 'edtRotatorUDP',
   # the station profile being edited -- per-profile, not global
   'cbxProfile', 'cbxRadio1', 'cbxRadio2', 'cbxCW1', 'cbxCW2',
   'chkSpeedSync1', 'chkSpeedSync2', 'chkSO2R', 'chkAutoConnect',
   # the UDP destination being edited in lstUDPDestinations
   'chkUDPEnabled', 'chkUDPAllQSOs'
)

$missing = $controls |
   Where-Object { -not $registered.ContainsKey($_.Name) } |
   Where-Object { $NOT_A_SETTING -notcontains $_.Name }

if ($missing.Count -gt 0)
{
   Write-Host "  Lint-SearchIndex: $($missing.Count) designed control(s) reach neither the bindings nor the search index." -ForegroundColor Red
   foreach ($m in ($missing | Sort-Object Panel, Name))
   {
      Write-Host ("    {0,-24} {1,-12} on {2}" -f $m.Name, $m.Type, $m.Panel)
   }
   Write-Host ""
   Write-Host "  Each is invisible to the Preferences search box, and may not be saved at all."
   Write-Host "  Register it with ONE of:"
   Write-Host "    FBindings.Bind(<control>, '<settings key>')      -- it has a registered key"
   Write-Host "    AddHandWiredToSearchIndex(n, '<COMMAND>', <ctl>) -- it edits a CFGCA command directly"
   Write-Host "    AddStoreBackedToSearchIndex(n, <ctl>)           -- it is backed by a store property"
   exit 1
}

$excluded = ($controls | Where-Object { $NOT_A_SETTING -contains $_.Name }).Count
Write-Host ("  Lint-SearchIndex: {0} designed control(s) across {1} section panel(s) checked, every one is bound or indexed ({2} record-editor field(s) excluded by name)." -f `
            $controls.Count, ($controls | Select-Object -ExpandProperty Panel -Unique).Count, $excluded)
exit 0
