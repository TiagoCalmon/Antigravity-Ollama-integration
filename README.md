# Antigravity Local-LLM-First Optimizer (`antigravity-optimizer`)

Configures **Google Antigravity** (IDE, 2.0 App, and CLI) to prioritize a local GPU-accelerated **Ollama** installation across **all existing and future projects** on a machine.

Built and benchmarked for **6 GB VRAM NVIDIA GPUs** (e.g., `NVIDIA GeForce RTX 3050 6GB Laptop GPU` with `CUDA 12+`) paired with **32 GB System RAM**, and easily adaptable to any GPU tier.

---

## 1. Architecture Overview

When installed globally via [`scripts/install-global.ps1`](./scripts/install-global.ps1), this repository deploys a 4-layer customization bundle into `~/.gemini/`:

```text
~/.gemini/
├── GEMINI.md                                      # Layer 1: Global Always-On Rule (All Workspaces)
└── config/
    └── plugins/
        └── local-ollama/                          # Layer 2: Global Native Antigravity Plugin
            ├── plugin.json                        # Plugin Manifest
            ├── mcp_config.json                    # Layer 3: Global MCP Server Registration
            ├── rules/
            │   └── AGENTS.md                      # Plugin-Scoped Always-On Priority Rule
            ├── skills/
            │   └── local-llm-router/
            │       ├── SKILL.md                   # Layer 4: On-Demand Routing Skill
            │       └── scripts/
            │           └── invoke-ollama.ps1      # PowerShell Router with Live GPU Telemetry
            └── tools/
                └── ollama-mcp-server.mjs          # Zero-Dependency Node.js Stdio MCP Server
```

### Hardware-Aware Model Routing Table

| Task Profile | Target Local Model | Weight Size | Execution Profile (6 GB VRAM + 32 GB RAM) |
| :--- | :--- | :--- | :--- |
| **`code`** (Coding, Refactoring, Tests, Regex, SQL, Scripts) | `qwen2.5-coder:7b-instruct-q3_K_M` | `3.8 GB` | **100% GPU VRAM** (`num_ctx=4096`, `~28 tok/s`, zero CPU spill) |
| **`general`** (Summarization, Docs, Multimodal) | `gemma4:e4b` | `6.6 GB` | **Primary GPU** (`CUDA0`) |
| **`deep`** (Complex Architecture & Deep Reasoning) | `gemma4:26b` | `18 GB` | **Hybrid MoE (GPU + 32 GB RAM)** (~3.8B active params/token) |

---

## 2. How to Install on Another Machine

### Prerequisites
1. **NVIDIA GPU Driver** (`CUDA 12+` recommended; verify with `nvidia-smi`).
2. **Ollama** installed and running (`http://127.0.0.1:11434`).
3. **Node.js `v18+`** (used by the zero-dependency `ollama-mcp-server.mjs` MCP server; verify with `node --version`).
4. **Google Antigravity** installed.

---

### Step 1: Clone This Repository
```powershell
git clone <your-repo-url> antigravity-optimizer
cd antigravity-optimizer
```

### Step 2: Run the One-Command Global Installer
Run [`scripts/install-global.ps1`](./scripts/install-global.ps1) in PowerShell.
* Pass `-ConfigureOllamaEnv` to set `OLLAMA_FLASH_ATTENTION=1`, `OLLAMA_KV_CACHE_TYPE=q8_0`, and `OLLAMA_NUM_PARALLEL=1`.
* Pass `-PullModels` to automatically download the three hardware-matched models (`qwen2.5-coder:7b-instruct-q3_K_M`, `gemma4:e4b`, and `gemma4:26b`).

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-global.ps1 -ConfigureOllamaEnv -PullModels
```

> **Note:** If you already have the models downloaded on the target machine, omit `-PullModels`:
> ```powershell
> powershell -ExecutionPolicy Bypass -File .\scripts\install-global.ps1 -ConfigureOllamaEnv
> ```

### Step 3: Restart Ollama & Antigravity
1. If you used `-ConfigureOllamaEnv`, restart the **Ollama** tray app / service so `OLLAMA_FLASH_ATTENTION=1` and `OLLAMA_KV_CACHE_TYPE=q8_0` take effect.
2. Restart **Antigravity** so it discovers the new global plugin at `~/.gemini/config/plugins/local-ollama/` and mounts the `local-ollama_local-ollama` MCP server across all projects.

---

## 3. How to Verify GPU Offloading & Antigravity Integration

### A. Verify via PowerShell Telemetry Router
Run the router script directly to confirm `100% GPU` VRAM residency and token generation speed:

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.gemini\config\plugins\local-ollama\skills\local-llm-router\scripts\invoke-ollama.ps1" -Task code -NumCtx 4096 -ShowTelemetry -Prompt "Write a Python binary search function with type hints."
```

Expected output:
```text
=== LOCAL OLLAMA TELEMETRY ===
Model         : qwen2.5-coder:7b-instruct-q3_K_M
Task Profile  : code (num_ctx=4096)
VRAM Offload  : 100% GPU (3843083467 / 3843083467 bytes)
Eval Speed    : 27.58 tokens/sec (108 tokens)
=== RESPONSE ===
...
```

### B. Verify via MCP Server (`ollama_status`)
Test the JSON-RPC MCP server from the terminal:

```powershell
'{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"ollama_status","arguments":{}}}' | node "$HOME\.gemini\config\plugins\local-ollama\tools\ollama-mcp-server.mjs"
```

### C. Verify Inside Antigravity Chat (Any Project)
Open **any** existing or brand-new project in Antigravity and ask:
* *"Check local Ollama GPU VRAM status using the MCP tool."*
* *"Use the local Qwen Coder model to write unit tests for this module."*

---

## 4. Customizing for Different GPU Tiers

If the target machine has a different GPU VRAM budget, edit the `TASK_MODELS` map in [`plugins/local-ollama/tools/ollama-mcp-server.mjs`](./plugins/local-ollama/tools/ollama-mcp-server.mjs) and [`plugins/local-ollama/skills/local-llm-router/scripts/invoke-ollama.ps1`](./plugins/local-ollama/skills/local-llm-router/scripts/invoke-ollama.ps1), then re-run `.\scripts\install-global.ps1`:

* **4 GB VRAM GPUs:** Use `qwen2.5-coder:3b` (`1.9 GB`) for `code` and `qwen3:4b` (`2.6 GB`) for `general`.
* **6 GB VRAM GPUs (Default):** Use `qwen2.5-coder:7b-instruct-q3_K_M` (`3.8 GB`) for 100% GPU coding, `gemma4:e4b` for general, and `gemma4:26b` (with 32 GB system RAM) for deep reasoning.
* **8 GB–12 GB VRAM GPUs:** Upgrade `code` to `qwen2.5-coder:7b` (`Q4_K_M`, `4.7 GB`) or `qwen2.5-coder:14b-instruct-q3_K_M`.
* **16 GB–24 GB+ VRAM GPUs:** Upgrade `code` to `qwen2.5-coder:14b` or `qwen2.5-coder:32b`, and run `gemma4:26b` 100% inside GPU VRAM.
