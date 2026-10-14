# Reads heaptrc's report, for Build-Tests.ps1 -Checked. Dot-source it.
#
# ONE THING HEAPTRC GETS WRONG, AND HOW THIS TELLS IT APART -- 2026-10-14.
#
# heaptrc (FPC 3.2.2, rtl/inc/heaptrc.pp) keeps one 32-bit field, sig, in every
# block's header, and gives it two meanings:
#
#   a RELEASED block   sig = ReleaseSig = $AAAAAAAA            (CheckFreeMemSize)
#   a LIVE block       sig = calculate_sig(pp), a CRC-32        (usecrc, the default)
#
# and on every free it tests for the first BEFORE the second. calculate_sig
# covers only the block's size, its 16 allocation return addresses and its
# tail -- NOT its address -- so a block whose CRC happens to be $AAAAAAAA is
# reported as "Marked memory at $X released ... freed again at" the first time
# it is freed, although it was never freed before. The odds are 2^-32 per
# distinct (size, call stack), and the result is fixed for a given binary,
# because the return addresses are: rebuild with one more line of code and it
# moves or vanishes. That is exactly what M10 S2 hit: the IndexOfName temp
# that TR4WSettings.BuildCommandMap makes in SettingsFreshInstall's heap test,
# size 34, has the signature $AAAAAAAA in that build and in no other.
#
# WHY NOT TURN IT OFF. usecrc := false would remove the collision and, with it,
# the TAIL CHECK -- the tail is checked only as part of the CRC -- so heap
# overruns would stop being reported at all. keepreleased exhausts a 32-bit
# address space on this suite (see Build-Tests.ps1). Neither is a fix.
#
# WHAT THIS DOES INSTEAD: it recomputes the signature from what heaptrc
# printed -- the size and all 16 return addresses, which dump_already_free
# prints as the "Call trace" and "was released at" halves (without
# keepreleased the second half is simply calls[9..16] of the ALLOCATION trace,
# not a release trace) -- and excuses the report only if the recomputed value
# IS $AAAAAAAA. A misread trace can only produce some other value, so the
# mistake this can make is to FAIL a collision, never to pass a real double
# free (bar the same 2^-32).

# no Set-StrictMode here: this file is dot-sourced, and a strict mode set at
# script scope would change the caller's rules too.
$script:HeaptrcCrcTable = $null

# AS UNSIGNED, AND SPELLED THIS WAY ON PURPOSE: Windows PowerShell 5 reads a
# hex literal above 0x7FFFFFFF as a NEGATIVE Int32, and a negative value cast
# to [uint32] throws.
$script:HeaptrcPoly       = [Convert]::ToUInt32('EDB88320', 16)
$script:HeaptrcSeed       = [Convert]::ToUInt32('FFFFFFFF', 16)
$script:HeaptrcReleaseSig = [Convert]::ToUInt32('AAAAAAAA', 16)

# heaptrc's MakeCRC32Tbl: the reflected CRC-32 polynomial $EDB88320.
function Get-HeaptrcCrcTable
   {
   if ($null -eq $script:HeaptrcCrcTable)
      {
      $table = New-Object 'uint32[]' 256
      for ($i = 0; $i -lt 256; $i++)
         {
         [uint32] $crc = $i
         for ($n = 0; $n -lt 8; $n++)
            {
            if (($crc -band 1) -ne 0)
               {
               $crc = [uint32] (($crc -shr 1) -bxor $script:HeaptrcPoly)
               }
            else
               {
               $crc = [uint32] ($crc -shr 1)
               }
            }
         $table[$i] = $crc
         }
      $script:HeaptrcCrcTable = $table
      }
   return $script:HeaptrcCrcTable
   }

# heaptrc's calculate_sig: seed $FFFFFFFF, NO final inversion, over the size
# (one ptruint), the 16 return addresses (one codepointer each) and the tail
# (tail_size = one ptruint, filled with dwords of AllocateSig = $DEADBEEF).
function Get-HeaptrcSignature
   {
   param(
      [uint64]   $Size,
      [uint64[]] $Calls,
      [int]      $PointerSize
   )

   $bytes = New-Object System.Collections.Generic.List[byte]
   $values = @($Size) + @($Calls)
   foreach ($v in $values)
      {
      for ($b = 0; $b -lt $PointerSize; $b++)
         {
         $bytes.Add([byte] (($v -shr (8 * $b)) -band 0xFF))
         }
      }
   for ($d = 0; $d -lt ($PointerSize / 4); $d++)
      {
      foreach ($tb in @(0xEF, 0xBE, 0xAD, 0xDE))
         {
         $bytes.Add([byte] $tb)
         }
      }

   $table = Get-HeaptrcCrcTable
   [uint32] $crc = $script:HeaptrcSeed
   foreach ($byte in $bytes)
      {
      $crc = [uint32] ($table[($crc -bxor $byte) -band 0xFF] -bxor ($crc -shr 8))
      }
   return $crc
   }

# One "Marked memory at $X released" report, read from the line that starts it.
# Returns $null when the text is not the shape dump_already_free prints, which
# the caller must treat as corruption: unreadable is not excusable.
function Read-HeaptrcReleasedReport
   {
   param(
      [string[]] $Lines,
      [int]      $Index
   )

   $head = [regex]::Match($Lines[$Index], '^\s*Marked memory at \$([0-9A-Fa-f]+) released')
   if (-not $head.Success) { return $null }
   if (($Index + 1) -ge $Lines.Count) { return $null }
   $trace = [regex]::Match($Lines[$Index + 1], '^\s*Call trace for block at \$([0-9A-Fa-f]+) size (\d+)')
   if (-not $trace.Success) { return $null }

   $first  = New-Object System.Collections.Generic.List[uint64]
   $second = New-Object System.Collections.Generic.List[uint64]
   $target = $first
   $freedAgain = -1
   for ($i = $Index + 2; $i -lt $Lines.Count; $i++)
      {
      $line = $Lines[$i]
      if ($line -match '^\s*was released at\s*$')
         {
         $target = $second
         continue
         }
      if ($line -match '^\s*freed again at\s*$')
         {
         $freedAgain = $i
         break
         }
      $addr = [regex]::Match($line, '^\s+\$([0-9A-Fa-f]+)')
      if (-not $addr.Success) { return $null }
      $target.Add([Convert]::ToUInt64($addr.Groups[1].Value, 16))
      }

   # Each half is printed without its nil entries, and a backtrace stops at
   # its first nil, so the missing ones are trailing: pad each half to 8. If
   # the first half is short the capture stopped there and the second half
   # must be empty; anything else is not a shape this can read.
   if (($freedAgain -lt 0) -or ($first.Count -gt 8) -or ($second.Count -gt 8)) { return $null }
   if (($first.Count -lt 8) -and ($second.Count -gt 0)) { return $null }
   $calls = New-Object 'uint64[]' 16
   for ($k = 0; $k -lt $first.Count;  $k++) { $calls[$k]     = $first[$k] }
   for ($k = 0; $k -lt $second.Count; $k++) { $calls[8 + $k] = $second[$k] }

   return [pscustomobject] @{
      Block      = $head.Groups[1].Value
      Size       = [uint64] $trace.Groups[2].Value
      Calls      = $calls
      FreedAgain = $freedAgain
   }
   }

# True when the report is heaptrc's ReleaseSig collision and nothing else.
function Test-HeaptrcReleaseSigCollision
   {
   param(
      $Report,
      [int] $PointerSize
   )

   if ($null -eq $Report) { return $false }
   $sig = Get-HeaptrcSignature -Size $Report.Size -Calls $Report.Calls -PointerSize $PointerSize
   return ($sig -eq $script:HeaptrcReleaseSig)
   }

# THE PIN. The block M10 S2 tripped over, exactly as heaptrc printed it
# (build-out\tests-checked-run.log, 2026-10-14). Its signature IS ReleaseSig,
# so this must classify it as a collision; with one return address changed it
# must not. Run before every classification -- a verifier that has drifted
# from heaptrc's algorithm would otherwise excuse nothing, or worse.
function Test-HeaptrcVerifier
   {
   $sample = @(
      'Marked memory at $0BE88550 released',
      'Call trace for block at $0BE88550 size 34',
      '  $005D7A19', '  $005D665B', '  $004E00D0', '  $004DF163',
      '  $004DE7A9', '  $005AB948', '  $005ABA77', '  $00441869',
      ' was released at ',
      '  $00404029', '  $00441869', '  $00404029', '  $00404029',
      '  $00404029', '  $00404029', '  $0054C99A', '  $0054CB62',
      'freed again at',
      '  $004197BC'
   )
   $real = Read-HeaptrcReleasedReport -Lines $sample -Index 0
   if (-not (Test-HeaptrcReleaseSigCollision -Report $real -PointerSize 4)) { return $false }

   $altered = $sample.Clone()
   $altered[2] = '  $005D7A1A'
   $other = Read-HeaptrcReleasedReport -Lines $altered -Index 0
   if ($null -eq $other) { return $false }
   if (Test-HeaptrcReleaseSigCollision -Report $other -PointerSize 4) { return $false }

   return $true
   }
