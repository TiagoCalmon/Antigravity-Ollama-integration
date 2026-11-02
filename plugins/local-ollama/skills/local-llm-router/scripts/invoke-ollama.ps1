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

if ($ShowTelemetry) {
    $ps = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/ps" -Method Get
    $activeModel = $ps.models | Where-Object { $_.name -eq $Model } | Select-Object -First 1
    $vramPct = if ($activeModel -and $activeModel.size -gt 0) {
        [math]::Round(($activeModel.size_vram / $activeModel.size) * 100, 1)
    } else { 0 }
    $tokPerSec = if ($response.eval_duration -gt 0) {
        [math]::Round(($response.eval_count / ($response.eval_duration / 1e9)), 2)
    } else { 0 }

    Write-Output "=== LOCAL OLLAMA TELEMETRY ==="
    Write-Output "Model         : $($response.model)"
    Write-Output "Task Profile  : $Task (num_ctx=$NumCtx)"
    Write-Output "VRAM Offload  : $vramPct% GPU ($($activeModel.size_vram) / $($activeModel.size) bytes)"
    Write-Output "Eval Speed    : $tokPerSec tokens/sec ($($response.eval_count) tokens)"
    Write-Output "=== RESPONSE ==="
}

Write-Output $response.response
