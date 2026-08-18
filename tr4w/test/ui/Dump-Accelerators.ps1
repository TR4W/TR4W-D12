<#
.SYNOPSIS
   Dumps TR4W's 'T' accelerator table out of the built binary, as data.

.DESCRIPTION
   The keystroke for a command is currently stated TWICE: once in the 'T'
   ACCELERATORS resource inside tr4w_eng.RES, and again as a caption constant in
   uMenu.pas (`RC_EXIT_HK = #9'Alt+X'`, ~60 of them). They are maintained in
   parallel with no generator -- commit 344ddea9, "update Alt+O accelerator ID to
   10603 in all language files", is what a drift costs.

   Phase 2 of the Win32-to-LCL migration collapses the two into one Pascal table
   carrying id, modifier, key AND display text, because `TranslateAccelerator`
   dies with the message loop and `TMenuItem.ShortCut` has to be carrying every
   binding before that happens.

   SEED THAT TABLE FROM THIS DUMP, NOT FROM THE `_HK` CONSTANTS. Two reasons,
   and the first is decisive:

     * at least one binding exists ONLY in the binary. tr4w.dpr:1056 says so in
       code -- "Ctrl+T -> menu_repeat_pota_parks is defined directly in the .res
       file" -- so a transcription approach silently loses it;
     * the display constants are the very thing that may be wrong, so they
       cannot also be the oracle.

   READ-ONLY. It loads the executable as a data file (LOAD_LIBRARY_AS_DATAFILE),
   reads the resource, and runs nothing.

.EXAMPLE
   .\Dump-Accelerators.ps1
   .\Dump-Accelerators.ps1 -Csv accel.csv
#>

param(
   [string] $Exe = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'target\tr4w.exe'),
   [string] $Table = 'T',
   [string] $Csv
)

Set-StrictMode -Version Latest

Add-Type -Namespace Win32 -Name Accel -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern System.IntPtr LoadLibraryExW(string f, System.IntPtr h, uint flags);
[DllImport("kernel32.dll")]
public static extern bool FreeLibrary(System.IntPtr h);
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern System.IntPtr LoadAcceleratorsW(System.IntPtr hInst, string name);
[DllImport("user32.dll")]
public static extern int CopyAcceleratorTableW(System.IntPtr hAccel, [Out] ACCEL[] dst, int n);
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential, Pack = 2)]
public struct ACCEL { public byte fVirt; public ushort key; public ushort cmd; }
'@

if (-not (Test-Path -LiteralPath $Exe)) {
   Write-Output "Dump-Accelerators: no binary at $Exe -- run FullBuild.ps1 first"
   exit 1
}

# LOAD_LIBRARY_AS_DATAFILE (0x2): map the image for resource reading only. It
# does not run DllMain and does not start the program.
$mod = [Win32.Accel]::LoadLibraryExW($Exe, [IntPtr]::Zero, 0x2)
if ($mod -eq [IntPtr]::Zero) {
   Write-Output "Dump-Accelerators: could not map $Exe as a data file"
   exit 1
}

try {
   $h = [Win32.Accel]::LoadAcceleratorsW($mod, $Table)
   if ($h -eq [IntPtr]::Zero) {
      Write-Output "Dump-Accelerators: no ACCELERATORS resource named '$Table' in $Exe"
      exit 1
   }

   $count = [Win32.Accel]::CopyAcceleratorTableW($h, $null, 0)
   $rows  = New-Object 'Win32.Accel+ACCEL[]' $count
   [void][Win32.Accel]::CopyAcceleratorTableW($h, $rows, $count)

   # fVirt flags, from WinUser.h.
   $FVIRTKEY = 0x01; $FSHIFT = 0x04; $FCONTROL = 0x08; $FALT = 0x10

   # Only the non-alphanumeric keys TR4W actually binds need naming.
   $VK = @{ 0x08 = 'Back'; 0x09 = 'Tab'; 0x0D = 'Enter'; 0x13 = 'Pause'; 0x1B = 'Esc'
            0x20 = 'Space'; 0x21 = 'PgUp'; 0x22 = 'PgDn'; 0x23 = 'End'
            0x24 = 'Home'; 0x25 = 'Left'; 0x26 = 'Up'; 0x27 = 'Right'
            0x28 = 'Down'; 0x2D = 'Ins'; 0x2E = 'Del'
            0xBB = '='; 0xBC = ','; 0xBD = '-'; 0xBE = '.'; 0xBF = '/'
            0xC0 = '`'; 0xDB = '['; 0xDC = '\'; 0xDD = ']'; 0xDE = "'" }

   $out = foreach ($r in $rows) {
      $mods = @()
      if ($r.fVirt -band $FCONTROL) { $mods += 'Ctrl' }
      if ($r.fVirt -band $FALT)     { $mods += 'Alt' }
      if ($r.fVirt -band $FSHIFT)   { $mods += 'Shift' }

      # A virtual key is a VK_ code; without FVIRTKEY the value is an ASCII
      # character. Reporting the raw number as if it were a character is how a
      # dump like this misleads, so say which it is.
      if ($r.fVirt -band $FVIRTKEY) {
         # A local VK map rather than [System.Windows.Forms.Keys]: pulling in
         # WinForms to name a key would be a heavy dependency for a dump, and
         # its enum spells the letters 'A'..'Z' but the function keys 'F1'..
         # differently from what an operator reads on a menu.
         if ($r.key -ge 0x70 -and $r.key -le 0x87) { $keyName = 'F' + ($r.key - 0x6F) }
         elseif ($r.key -ge 0x30 -and $r.key -le 0x5A) { $keyName = [string][char]$r.key }
         elseif ($VK.ContainsKey([int]$r.key)) { $keyName = $VK[[int]$r.key] }
         else { $keyName = ('VK_0x{0:X2}' -f $r.key) }
         $kind = 'VK'
      }
      else {
         $keyName = [char]$r.key
         $kind = 'ASCII'
      }

      [pscustomobject]@{
         Command = $r.cmd
         Display = (($mods + $keyName) -join '+')
         Key     = $keyName
         KeyCode = $r.key
         Kind    = $kind
         Ctrl    = [bool]($r.fVirt -band $FCONTROL)
         Alt     = [bool]($r.fVirt -band $FALT)
         Shift   = [bool]($r.fVirt -band $FSHIFT)
         fVirt   = $r.fVirt
      }
   }

   $out = @($out | Sort-Object Command)

   if ($Csv) {
      $out | Export-Csv -LiteralPath $Csv -NoTypeInformation -Encoding UTF8
      Write-Output ("Dump-Accelerators: {0} binding(s) -> {1}" -f $out.Count, $Csv)
   }
   else {
      $out | Format-Table Command, Display, Kind, KeyCode -AutoSize | Out-String -Width 200 | Write-Output
      Write-Output ("Dump-Accelerators: {0} binding(s) in table '{1}' of {2}" -f $out.Count, $Table, (Split-Path $Exe -Leaf))
   }
}
finally {
   [void][Win32.Accel]::FreeLibrary($mod)
}
exit 0
