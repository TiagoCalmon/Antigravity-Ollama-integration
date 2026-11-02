---
name: local-llm-router
description: >-
  Routes coding, refactoring, summarization, and reasoning tasks to the local
  GPU-accelerated Ollama instance across all projects. Activate this skill
  whenever a subtask can be offloaded to a local LLM or when the user asks to
  use or verify local Ollama models.
---

# Global Local LLM Router Skill

Use this skill in any workspace to execute subtasks on the local Ollama server (`http://127.0.0.1:11434`) using hardware-matched models.

## Model Selection Matrix

1. **`code` (`qwen2.5-coder:7b-instruct-q3_K_M`, 3.8 GB)**
   - Fits **100% in 6GB GPU VRAM** (`num_ctx=4096` or `8192`).
   - Use for: code generation, unit tests, refactoring, regex, SQL, shell scripts.
2. **`general` (`gemma4:e4b`, 6.6 GB)**
   - Primary GPU multimodal/general model.
   - Use for: summarization, documentation drafting, translation, general Q&A.
3. **`deep` (`gemma4:26b`, 18 GB MoE)**
   - Hybrid GPU + 32 GB System RAM (~3.8B active parameters per token).
   - Use for: complex architectural reviews and deep multi-step reasoning.

## How to Invoke From Any Project

### Option A: Via MCP Tool (`local-ollama_local-ollama`)
Call `ollama_generate` with `task: "code" | "general" | "deep"` and `prompt`, or `ollama_status` to inspect live VRAM residency.

### Option B: Via Global PowerShell Helper Script
Run the global router script:

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.gemini\config\plugins\local-ollama\skills\local-llm-router\scripts\invoke-ollama.ps1" -Task code -NumCtx 4096 -ShowTelemetry -Prompt "Your prompt here"
```
