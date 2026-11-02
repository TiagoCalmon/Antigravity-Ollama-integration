param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("code", "general", "deep")]
    [string]$Task = "code",

    [Parameter(Mandatory=$false)]
    [string]$Model = "",

    [Parameter(Mandatory=$true)]
    [string]$Prompt,

    [Parameter(Mandatory=$false)]
    [int]$NumCtx = 4096,

    [Parameter(Mandatory=$false)]
    [switch]$ShowTelemetry
)

$ErrorActionPreference = "Stop"

if (-not $Model) {
    switch ($Task) {
        "code"    { $Model = "qwen2.5-coder:7b-instruct-q3_K_M" }
        "general" { $Model = "gemma4:e4b" }
        "deep"    { $Model = "gemma4:26b" }
    }
}

$body = @{
    model   = $Model
    prompt  = $Prompt
    stream  = $false
    options = @{
        num_ctx = $NumCtx
    }
} | ConvertTo-Json -Depth 5

$response = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method Post -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($body))

# Record into cumulative global token ledger (~/.gemini/antigravity/scratch/ollama_usage.json)
$UsageFile = Join-Path $HOME ".gemini\antigravity\scratch\ollama_usage.json"
$pTokens = if ($null -ne $response.prompt_eval_count) { [int]$response.prompt_eval_count } else { 0 }
$cTokens = if ($null -ne $response.eval_count) { [int]$response.eval_count } else { 0 }
$tTokens = $pTokens + $cTokens
$wsKey   = (Get-Location).Path

if (Test-Path $UsageFile) {
    $stats = Get-Content $UsageFile -Raw | ConvertFrom-Json
} else {
    $stats = [PSCustomObject]@{
        totals       = [PSCustomObject]@{ requests = 0; prompt_tokens = 0; completion_tokens = 0; total_tokens = 0 }
        by_model     = [PSCustomObject]@{}
        by_workspace = [PSCustomObject]@{}
        last_updated = $null
    }
}

$stats.totals.requests          += 1
$stats.totals.prompt_tokens     += $pTokens
$stats.totals.completion_tokens += $cTokens
$stats.totals.total_tokens      += $tTokens

$mName = $response.model
if (-not ($stats.by_model.PSObject.Properties.Name -contains $mName)) {
    $stats.by_model | Add-Member -NotePropertyName $mName -NotePropertyValue ([PSCustomObject]@{
        requests = 0; prompt_tokens = 0; completion_tokens = 0; total_tokens = 0
    })
}
$stats.by_model.$mName.requests          += 1
$stats.by_model.$mName.prompt_tokens     += $pTokens
$stats.by_model.$mName.completion_tokens += $cTokens
$stats.by_model.$mName.total_tokens      += $tTokens

if (-not $stats.PSObject.Properties.Name -contains "by_workspace") {
    $stats | Add-Member -NotePropertyName "by_workspace" -NotePropertyValue ([PSCustomObject]@{})
}
if (-not ($stats.by_workspace.PSObject.Properties.Name -contains $wsKey)) {
    $stats.by_workspace | Add-Member -NotePropertyName $wsKey -NotePropertyValue ([PSCustomObject]@{
        requests = 0; prompt_tokens = 0; completion_tokens = 0; total_tokens = 0
    })
}
$stats.by_workspace.$wsKey.requests          += 1
$stats.by_workspace.$wsKey.prompt_tokens     += $pTokens
$stats.by_workspace.$wsKey.completion_tokens += $cTokens
$stats.by_workspace.$wsKey.total_tokens      += $tTokens

$stats.last_updated = (Get-Date).ToString("o")
$stats | ConvertTo-Json -Depth 6 | Set-Content -Path $UsageFile -Encoding UTF8

if ($ShowTelemetry) {
    $ps = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/ps" -Method Get
    $activeModel = $ps.models | Where-Object { $_.name -eq $Model } | Select-Object -First 1
    $vramPct = if ($activeModel -and $activeModel.size -gt 0) {
        [math]::Round(($activeModel.size_vram / $activeModel.size) * 100, 1)
    } else { 0 }
    $tokPerSec = if ($response.eval_duration -gt 0) {
        [math]::Round(($cTokens / ($response.eval_duration / 1e9)), 2)
    } else { 0 }

    Write-Output "=== LOCAL OLLAMA TELEMETRY ==="
    Write-Output "Model            : $($response.model)"
    Write-Output "Task Profile     : $Task (num_ctx=$NumCtx)"
    Write-Output "VRAM Offload     : $vramPct% GPU ($($activeModel.size_vram) / $($activeModel.size) bytes)"
    Write-Output "Call Tokens      : $pTokens prompt + $cTokens completion = $tTokens total ($tokPerSec tok/s)"
    Write-Output "Cumulative Usage : $($stats.totals.total_tokens) tokens across $($stats.totals.requests) requests"
    Write-Output "=== RESPONSE ==="
}

Write-Output $response.response
