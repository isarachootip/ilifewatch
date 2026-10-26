param([string]$name, [string]$tap = "", [int]$wait = 2, [string]$key = "", [string]$swipe = "")
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$d = "T1051128GB25461581055"
$out = "C:\atgv\watch_care\docs\manual_screens"
if ($key) { & $adb -s $d shell input keyevent $key }
if ($tap) { $xy = $tap -split ","; & $adb -s $d shell input tap $xy[0] $xy[1] }
if ($swipe) { $s = $swipe -split ","; & $adb -s $d shell input swipe $s[0] $s[1] $s[2] $s[3] 400 }
Start-Sleep -Seconds $wait
if ($name) {
  cmd /c "`"$adb`" -s $d exec-out screencap -p > `"$out\$name.png`""
  & $adb -s $d shell uiautomator dump /sdcard/ui.xml | Out-Null
  & $adb -s $d pull /sdcard/ui.xml "$out\$name.xml" | Out-Null
  "$name " + (Get-Item "$out\$name.png").Length
}
