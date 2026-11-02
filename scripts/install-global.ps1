param(
    [Parameter(Mandatory=$false)]
    [switch]$PullModels,

    [Parameter(Mandatory=$false)]
    [switch]$ConfigureOllamaEnv
)

$ErrorActionPreference = "Stop"

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$GeminiHome = Join-Path $HOME ".gemini"
$PluginDest = Join-Path $GeminiHome "config\plugins\local-ollama"
$PluginSrc  = Join-Path $RepoRoot "plugins\local-ollama"

Write-Host "==> Installing Antigravity Global Local-LLM-First Configuration..." -ForegroundColor Cyan

if ($ConfigureOllamaEnv) {
    Write-Host "==> Applying Ollama GPU optimization environment variables..." -ForegroundColor Yellow
    [System.Environment]::SetEnvironmentVariable("OLLAMA_FLASH_ATTENTION", "1", "User")
    [System.Environment]::SetEnvironmentVariable("OLLAMA_KV_CACHE_TYPE", "q8_0", "User")
    [System.Environment]::SetEnvironmentVariable("OLLAMA_NUM_PARALLEL", "1", "User")
}

# 1. Copy plugin bundle into ~/.gemini/config/plugins/local-ollama
New-Item -ItemType Directory -Force -Path $PluginDest | Out-Null
Copy-Item -Path "$PluginSrc\*" -Destination $PluginDest -Recurse -Force

# 2. Generate mcp_config.json with the current machine's resolved path
$McpServerPath = (Join-Path $PluginDest "tools\ollama-mcp-server.mjs") -replace "\\", "/"
$McpConfig = @{
    mcpServers = @{
        "local-ollama" = @{
            command = "node"
            args    = @($McpServerPath)
            env     = @{
                OLLAMA_HOST = "http://127.0.0.1:11434"
            }
        }
    }
} | ConvertTo-Json -Depth 5
Set-Content -Path (Join-Path $PluginDest "mcp_config.json") -Value $McpConfig -Encoding UTF8

# 3. Generate global ~/.gemini/GEMINI.md with the current machine's resolved script path
$RouterScriptPath = Join-Path $PluginDest "skills\local-llm-router\scripts\invoke-ollama.ps1"
$GlobalRule = @"
# Global Local-LLM-First Policy (Ollama GPU + System RAM)

Whenever working in any workspace on this machine (existing or future projects), prioritize delegating self-contained coding, refactoring, test generation, and summarization tasks to the local Ollama server (`http://127.0.0.1:11434`):

1. **Coding & Scripts (100% GPU VRAM)**: `qwen2.5-coder:7b-instruct-q3_K_M` (`num_ctx=4096`)
2. **General & Multimodal**: `gemma4:e4b`
3. **Deep Reasoning (Hybrid GPU + 32GB RAM MoE)**: `gemma4:26b`
4. **Global Helper Router (Available in All Projects)**:
   `powershell -ExecutionPolicy Bypass -File "$RouterScriptPath" -Task <code|general|deep> -NumCtx 4096 -ShowTelemetry -Prompt "<prompt>"`
5. **Global MCP Tools**: `ollama_generate` and `ollama_status` (from the global `local-ollama` MCP server).
"@
Set-Content -Path (Join-Path $GeminiHome "GEMINI.md") -Value $GlobalRule -Encoding UTF8

if ($PullModels) {
    Write-Host "==> Pulling recommended Ollama models..." -ForegroundColor Yellow
    ollama pull qwen2.5-coder:7b-instruct-q3_K_M
    ollama pull gemma4:e4b
    ollama pull gemma4:26b
}

Write-Host "==> Installation complete!" -ForegroundColor Green
Write-Host "    Global Rule  : $(Join-Path $GeminiHome 'GEMINI.md')"
Write-Host "    Global Plugin: $PluginDest"
Write-Host "    Restart Antigravity to load the global plugin and MCP server across all projects."
