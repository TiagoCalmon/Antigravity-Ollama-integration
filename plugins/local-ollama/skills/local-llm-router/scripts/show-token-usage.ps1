param(
    [Parameter(Mandatory=$false)]
    [switch]$Reset
)

$UsageFile = Join-Path $HOME ".gemini\antigravity\scratch\ollama_usage.json"

if ($Reset) {
    if (Test-Path $UsageFile) { Remove-Item $UsageFile -Force }
    Write-Host "Cumulative Ollama token counter reset." -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path $UsageFile)) {
    Write-Host "No token usage recorded yet at $UsageFile" -ForegroundColor Yellow
    exit 0
}

$stats = Get-Content $UsageFile -Raw | ConvertFrom-Json

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "   GLOBAL OLLAMA CUMULATIVE TOKEN COUNTER (ALL PROJS)" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Ledger File       : $UsageFile"
Write-Host "Last Updated      : $($stats.last_updated)"
Write-Host "Total Requests    : $($stats.totals.requests)"
Write-Host "Prompt Tokens     : $($stats.totals.prompt_tokens)"
Write-Host "Completion Tokens : $($stats.totals.completion_tokens)"
Write-Host "TOTAL TOKENS      : $($stats.totals.total_tokens)" -ForegroundColor Green
Write-Host ""
Write-Host "--- Breakdown by Local Model ---" -ForegroundColor Yellow
$stats.by_model.PSObject.Properties | ForEach-Object {
    [PSCustomObject]@{
        Model            = $_.Name
        Requests         = $_.Value.requests
        PromptTokens     = $_.Value.prompt_tokens
        CompletionTokens = $_.Value.completion_tokens
        TotalTokens      = $_.Value.total_tokens
    }
} | Format-Table -AutoSize

if ($stats.by_workspace) {
    Write-Host "--- Breakdown by Workspace ---" -ForegroundColor Yellow
    $stats.by_workspace.PSObject.Properties | ForEach-Object {
        [PSCustomObject]@{
            Workspace        = $_.Name
            Requests         = $_.Value.requests
            PromptTokens     = $_.Value.prompt_tokens
            CompletionTokens = $_.Value.completion_tokens
            TotalTokens      = $_.Value.total_tokens
        }
    } | Format-Table -AutoSize
}
