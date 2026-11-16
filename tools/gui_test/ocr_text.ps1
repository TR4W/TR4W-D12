# Read the text in one PNG with Windows.Media.Ocr and print one recognised line
# per output line (UTF-8). Used where the text under test is drawn by a control
# that has no window and no accessibility object -- an LCL TLabel such as
# Preferences > Station's lblStationProblem -- so neither the win32 tree nor UI
# Automation can read it. The caller keeps the raw output as evidence; OCR is
# a reading aid, so assertions match words, never the whole sentence.
param([Parameter(Mandatory = $true)][string]$Path)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime]
$null = [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]

$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
   $_.Name -eq "AsTask" -and $_.GetParameters().Count -eq 1 -and
   $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

function Await($operation, [Type]$type) {
   $task = $asTask.MakeGenericMethod($type).Invoke($null, @($operation))
   $null = $task.Wait(-1)
   return $task.Result
}

$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync((Resolve-Path -LiteralPath $Path).Path)) ([Windows.Storage.StorageFile])
$stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
try {
   $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
   $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
   $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new("en-US"))
   if ($null -eq $engine) {
      $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
   }
   if ($null -eq $engine) {
      throw "No Windows OCR engine is available for en-US"
   }
   $result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
   foreach ($line in $result.Lines) {
      Write-Output $line.Text
   }
}
finally {
   $stream.Dispose()
}
