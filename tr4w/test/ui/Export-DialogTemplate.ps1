<#
.SYNOPSIS
   Dumps a DIALOG/DIALOGEX template out of a compiled .RES so a form can be
   transcribed from the BYTES THAT SHIP, not from the .rc or from a screenshot.

.DESCRIPTION
   Phase 5 of the Win32-to-LCL migration converts the three dialogs that really
   do have a resource template -- 46 (Edit QSO), 66 (CAT) and 73 (Sync log).
   Every other dialog in TR4W is built by hand in its WM_INITDIALOG, so those
   could be read straight out of the Pascal. These three cannot: their geometry
   is in `res\tr4w_eng.res`, which is a binary the compiler links and nobody
   reads.

   THE OBVIOUS SHORTCUT IS WRONG. `res\Tr4w.rc` looks like the source of that
   .RES and is not -- CLAUDE.md says it is not a build input, and this script is
   how that was measured rather than assumed. For dialog 46 the two disagree:

     .rc  : 388 x 222 dialog units, 66 controls
     .RES : 389 x 254 dialog units, 69 controls

   AND THE SAME DRIFT HAPPENED BETWEEN THE ELEVEN .RES FILES. Running this over
   every one of them reconstructs the history exactly, and it is not pretty:

     Tr4w.rc                    388 x 222   66 controls   (the original)
     tr4w_ger.RES, _ukr.RES     388 x 222   67 controls   (+ X-QSO)
     the other nine .RES        389 x ~250  69 controls   (+ X-QSO, + Operator)

   So X-QSO (170) was added by hand to all eleven; the Operator label and edit
   (168, 167) reached nine of them and MISSED German and Ukrainian; and the .rc
   was never updated for either. Two separate hand-edits, two separate misses.
   That is not carelessness -- it is what eleven copies of one dialog COST, and
   it is the concrete argument for the .lfm: one form retires all eleven.

   Moot in practice today, because only tr4w_eng.RES is linked (one English
   build since 2026-08-13) -- but worth knowing before anyone reaches for a
   non-English .RES as a reference. Use eng, or use the live window.
   The three controls the .rc does not have are X-QSO (170) and the Operator
   label and edit (168, 167) -- all three of which uEditQSO.pas READS AND
   WRITES. So the .rc is stale by at least one feature, and a form transcribed
   from it would have lost the X-QSO flag with nothing to say so. The .RES is
   the authority because the .RES is what DialogBox() is handed.

   WHAT YOU GET is one row per control: id, window class, position and size in
   DIALOG UNITS, the style and extended-style words, and the caption. Dialog
   units are NOT pixels -- see -Pixels below.

.PARAMETER ResFile
   The compiled resource. Defaults to tr4w\res\tr4w_eng.res.

.PARAMETER Id
   Numeric resource id of the dialog (46, 66, 73). Omit to list what the file
   contains and exit.

.PARAMETER Pixels
   Also print pixel coordinates. The conversion is the dialog manager's own:

      x_px = x_dlu * baseunitX / 4        y_px = y_dlu * baseunitY / 8

   where the base units come from the AVERAGE CHARACTER SIZE OF THE DIALOG'S
   FONT, not the system font -- which for these three templates is MS Sans
   Serif 8, giving 6 and 13. That is why the numbers are 1.5 and 1.625 and not
   something rounder. Override with -BaseUnitX / -BaseUnitY if a template ever
   declares a different face.

   Treat the pixel column as a STARTING POINT for an .lfm, not as gospel: the
   real dialog is also subject to the running machine's DPI. Dump-WindowTree.ps1
   against the live window is the check.

.EXAMPLE
   .\Export-DialogTemplate.ps1                 # what dialogs does the .RES hold
   .\Export-DialogTemplate.ps1 -Id 46 -Pixels  # the Edit QSO template
#>
[CmdletBinding()]
param(
   [string] $ResFile,
   [int]    $Id,
   [switch] $Pixels,
   [int]    $BaseUnitX = 6,
   [int]    $BaseUnitY = 13
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ResFile) {
   # $PSScriptRoot is tr4w\test\ui, so two levels up is tr4w itself.
   $tr4w    = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
   $ResFile = Join-Path $tr4w 'res\tr4w_eng.res'
}
if (-not (Test-Path $ResFile)) { throw "resource file not found: $ResFile" }

$bytes = [IO.File]::ReadAllBytes($ResFile)

# --- little readers over the byte array ------------------------------------
# A .RES is a flat run of [DWORD DataSize][DWORD HeaderSize][type][name][...]
# with every record DWORD-aligned. Type and name are each either an ordinal
# (0xFFFF followed by a WORD) or a NUL-terminated UTF-16 string.

function Get-U16([int] $p) { [BitConverter]::ToUInt16($bytes, $p) }
function Get-U32([int] $p) { [BitConverter]::ToUInt32($bytes, $p) }
function Get-I16([int] $p) { [BitConverter]::ToInt16($bytes, $p) }
function Align4([int] $p)  { return ($p + 3) -band (-bnot 3) }

# Returns @{ Value = <int or string>; Next = <offset> }
function Read-NameOrOrd([int] $p) {
   $w = Get-U16 $p
   if ($w -eq 0x0000) { return @{ Value = ''; Next = $p + 2 } }
   if ($w -eq 0xFFFF) { return @{ Value = [int](Get-U16 ($p + 2)); Next = $p + 4 } }
   $sb = New-Object Text.StringBuilder
   while ($true) {
      $ch = Get-U16 $p; $p += 2
      if ($ch -eq 0) { break }
      [void]$sb.Append([char]$ch)
   }
   return @{ Value = $sb.ToString(); Next = $p }
}

# --- walk the .RES and index its dialogs -----------------------------------
$RT_DIALOG = 5
$dialogs = @{}
$pos = 0
while ($pos + 8 -le $bytes.Length) {
   $dataSize = Get-U32 $pos
   $hdrSize  = Get-U32 ($pos + 4)
   if ($hdrSize -lt 8 -or ($pos + $hdrSize) -gt $bytes.Length) { break }

   $r = Read-NameOrOrd ($pos + 8)
   $rtype = $r.Value
   $r = Read-NameOrOrd $r.Next
   $rname = $r.Value

   $body = $pos + $hdrSize
   if ($rtype -is [int] -and $rtype -eq $RT_DIALOG) {
      $dialogs[$rname] = @{ Offset = $body; Size = [int]$dataSize }
   }
   $pos = Align4 ($body + $dataSize)
}

if (-not $PSBoundParameters.ContainsKey('Id')) {
   Write-Output "$ResFile holds $($dialogs.Count) dialog template(s):"
   foreach ($k in ($dialogs.Keys | Sort-Object)) {
      Write-Output ("  id {0,-6} {1,6} bytes" -f $k, $dialogs[$k].Size)
   }
   Write-Output ''
   Write-Output 'Re-run with -Id <n> to dump one.'
   exit 0
}

if (-not $dialogs.ContainsKey($Id)) {
   throw "dialog $Id is not in $ResFile (it holds: $(($dialogs.Keys | Sort-Object) -join ', '))"
}

# --- parse the template ----------------------------------------------------
# DLGTEMPLATEEX announces itself with dlgVer = 1 and signature = 0xFFFF in the
# first two words -- which, read as the plain DLGTEMPLATE's `style` DWORD, is
# the impossible value 0xFFFF0001. That is the documented way to tell them
# apart, and all three TR4W templates are EX.
$p    = $dialogs[$Id].Offset
$stop = $p + $dialogs[$Id].Size

$isEx = ((Get-U16 $p) -eq 1) -and ((Get-U16 ($p + 2)) -eq 0xFFFF)
if (-not $isEx) { throw "dialog $Id is a plain DLGTEMPLATE; this script only parses DLGTEMPLATEEX" }

$p += 4                       # dlgVer, signature
$p += 4                       # helpID
$dlgExStyle = Get-U32 $p; $p += 4
$dlgStyle   = Get-U32 $p; $p += 4
$count = Get-U16 $p; $p += 2
$dx = Get-I16 $p; $p += 2
$dy = Get-I16 $p; $p += 2
$dcx = Get-I16 $p; $p += 2
$dcy = Get-I16 $p; $p += 2

$r = Read-NameOrOrd $p; $p = $r.Next          # menu
$r = Read-NameOrOrd $p; $p = $r.Next          # window class
$r = Read-NameOrOrd $p; $p = $r.Next
$title = $r.Value

$DS_SETFONT = 0x40
$fontDesc = '(none)'
if ($dlgStyle -band $DS_SETFONT) {
   $pts = Get-U16 $p; $p += 2
   $p += 2                                    # weight
   $p += 2                                    # italic, charset
   $r = Read-NameOrOrd $p; $p = $r.Next
   $fontDesc = "$pts pt $($r.Value)"
}

# The six predefined control classes are stored as ordinals.
$stdClass = @{ 0x80 = 'BUTTON'; 0x81 = 'EDIT'; 0x82 = 'STATIC';
               0x83 = 'LISTBOX'; 0x84 = 'SCROLLBAR'; 0x85 = 'COMBOBOX' }

$rows = @()
for ($i = 0; $i -lt $count; $i++) {
   $p = Align4 $p
   if ($p + 24 -gt $stop) { throw "template $Id is truncated at control $i" }

   $p += 4                                    # helpID
   $exStyle = Get-U32 $p; $p += 4
   $style   = Get-U32 $p; $p += 4
   $cx_ = Get-I16 $p; $p += 2
   $cy_ = Get-I16 $p; $p += 2
   $cw_ = Get-I16 $p; $p += 2
   $ch_ = Get-I16 $p; $p += 2
   $cid = Get-U32 $p; $p += 4

   $r = Read-NameOrOrd $p; $p = $r.Next
   $cls = $r.Value
   if ($cls -is [int] -and $stdClass.ContainsKey($cls)) { $cls = $stdClass[$cls] }

   $r = Read-NameOrOrd $p; $p = $r.Next
   $cap = $r.Value

   $extra = Get-U16 $p; $p += 2 + $extra      # creation data, skipped

   $rows += [pscustomobject]@{
      Id      = [int]$cid
      Class   = "$cls"
      X       = $cx_
      Y       = $cy_
      CX      = $cw_
      CY      = $ch_
      PX      = [int][Math]::Round($cx_ * $BaseUnitX / 4)
      PY      = [int][Math]::Round($cy_ * $BaseUnitY / 8)
      PCX     = [int][Math]::Round($cw_ * $BaseUnitX / 4)
      PCY     = [int][Math]::Round($ch_ * $BaseUnitY / 8)
      Style   = ('0x{0:X8}' -f $style)
      ExStyle = ('0x{0:X8}' -f $exStyle)
      Caption = "$cap"
   }
}

Write-Output ("dialog {0}: '{1}'" -f $Id, $title)
Write-Output ("  {0} x {1} dialog units, {2} control(s), font {3}" -f $dcx, $dcy, $count, $fontDesc)
if ($Pixels) {
   Write-Output ("  {0} x {1} pixels at baseunits {2}/{3}" -f `
      [int][Math]::Round($dcx * $BaseUnitX / 4), [int][Math]::Round($dcy * $BaseUnitY / 8), $BaseUnitX, $BaseUnitY)
}
Write-Output ''

$sorted = $rows | Sort-Object Y, X
if ($Pixels) {
   $sorted | Format-Table Id, Class, X, Y, CX, CY, PX, PY, PCX, PCY, Style, ExStyle, Caption -AutoSize
} else {
   $sorted | Format-Table Id, Class, X, Y, CX, CY, Style, ExStyle, Caption -AutoSize
}

if ($p -gt $stop) { throw "parser overran the resource by $($p - $stop) byte(s) -- the dump above is not trustworthy" }
Write-Output ("Export-DialogTemplate: {0} control(s), {1} of {2} byte(s) consumed." -f $rows.Count, ($p - $dialogs[$Id].Offset), $dialogs[$Id].Size)
