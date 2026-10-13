$ErrorActionPreference = 'SilentlyContinue'
$csvText = [System.IO.File]::ReadAllText('C:\Users\pc\Desktop\LibreTV\new_sources.csv', [System.Text.Encoding]::UTF8)
$rows = $csvText.Trim() -split "`n" | Select-Object -Skip 1
$items = @()
foreach ($line in $rows) {
    $parts = $line.Trim() -split ',', 3
    if ($parts.Count -ge 3) {
        $items += [PSCustomObject]@{ id = $parts[0].Trim(); name = $parts[1].Trim(); url = $parts[2].Trim() }
    }
}
Write-Output ("TOTAL_ITEMS=" + $items.Count)
$jobs = @()
foreach ($s in $items) {
    $jobs += Start-Job -ScriptBlock {
        param($id, $name, $url)
        $u = $url.TrimEnd('/')
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $r = Invoke-WebRequest -Uri ($u + "?ac=videolist&wd=test") -UseBasicParsing -TimeoutSec 15 -Headers @{ "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
            $sw.Stop()
            $c = $r.Content; if ($c -is [byte[]]) { $c = [System.Text.Encoding]::UTF8.GetString($c) }
            $total = -1
            if ($c -match '"total":(\d+)') { $total = [int]$matches[1] }
            $code = -1
            if ($c -match '"code":(\d+)') { $code = [int]$matches[1] }
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            Write-Output ("{0}`t{1}`t{2}`t{3}ms`tcode={4}`ttotal={5}" -f $id, $name, $r.StatusCode, $sw.ElapsedMilliseconds, $code, $total)
        } catch {
            $sw.Stop()
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            Write-Output ("{0}`t{1}`tERR`t{2}ms`t{3}" -f $id, $name, $sw.ElapsedMilliseconds, $_.Exception.Message)
        }
    } -ArgumentList $s.id, $s.name, $s.url
}
$jobs | Wait-Job -Timeout 150 | Out-Null
$jobs | Receive-Job
$jobs | Remove-Job -Force