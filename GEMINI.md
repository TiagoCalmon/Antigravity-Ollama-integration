# Local-LLM-First Policy (Ollama on RTX 3050 6GB + 32GB RAM)

This environment is configured to **prioritize local LLM execution via Ollama (`http://127.0.0.1:11434`)** over cloud model calls whenever performing self-contained coding, drafting, summarization, or analysis subtasks.

## 1. Hardware-Aware Local Model Routing Table

Always select the local model that matches the task and fits the hardware budget (`NVIDIA GeForce RTX 3050 6GB Laptop GPU` with `CUDA0`, `OLLAMA_FLASH_ATTENTION=1`, `OLLAMA_KV_CACHE_TYPE=q8_0`, plus `32 GB` system RAM):

| Task Category | Target Local Model | Footprint | Execution Profile |
| :--- | :--- | :--- | :--- |
| **Coding, Refactoring, Unit Tests, Regex, SQL, Scripts** | `qwen2.5-coder:7b-instruct-q3_K_M` | `3.8 GB` | **100% GPU VRAM** (Fastest, zero CPU spill) |
| **General Text, Summarization, Docs, Multimodal** | `gemma4:e4b` | `6.6 GB` | **Primary GPU** (General & vision tasks) |
| **Complex Architecture & Deep Reasoning** | `gemma4:26b` | `18 GB` | **Hybrid MoE (GPU + 32GB RAM)** (~3.8B active params/token) |

## 2. Execution Priority Rules

1. **Delegate Subtasks Locally First**:
   - Before generating boilerplate code, unit tests, docstrings, commit messages, data transformations, or file summaries directly in the cloud model context, prefer invoking the local Ollama router:
     - Via MCP tool: `ollama_generate` (from the `local-ollama` MCP server)
     - Or via helper script: `powershell -ExecutionPolicy Bypass -File scripts/invoke-ollama.ps1 -Task <code|general|deep> -Prompt "<prompt>"`
2. **Verify GPU Offloading**:
   - Ensure `ollama ps` (or `/api/ps`) reports GPU VRAM allocation (`size_vram > 0`) on `NVIDIA GeForce RTX 3050 6GB Laptop GPU`.
   - For `qwen2.5-coder:7b-instruct-q3_K_M`, keep `num_ctx` at `8192` (or `4096`) to guarantee **100% GPU VRAM** execution with zero CPU layer offloading.
