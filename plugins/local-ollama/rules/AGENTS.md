# Global Local-LLM-First Policy (Plugin Scope — All Workspaces)

Whenever operating in any project or workspace on this machine, prioritize delegating self-contained coding, refactoring, test generation, documentation drafting, and summarization subtasks to the local Ollama instance (`http://127.0.0.1:11434`) before using cloud models:

| Task Category | Target Local Model | Hardware Execution Profile |
| :--- | :--- | :--- |
| **Coding, Refactoring, Tests, Regex, SQL, Scripts** | `qwen2.5-coder:7b-instruct-q3_K_M` (`3.8 GB`) | **100% GPU VRAM** (`num_ctx=4096`, 6GB+ GPU) |
| **General Text, Summarization, Docs, Multimodal** | `gemma4:e4b` (`6.6 GB`) | **Primary GPU** (`CUDA0`) |
| **Complex Architecture & Deep Reasoning** | `gemma4:26b` (`18 GB` MoE) | **Hybrid GPU + 32 GB System RAM** (~3.8B active params/token) |

## Invocation Methods
1. **MCP Tools**: Call `ollama_generate` (`task: "code" | "general" | "deep"`) or `ollama_status` from the `local-ollama_local-ollama` MCP server.
2. **Global CLI Router**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File "$HOME\.gemini\config\plugins\local-ollama\skills\local-llm-router\scripts\invoke-ollama.ps1" -Task code -NumCtx 4096 -ShowTelemetry -Prompt "<prompt>"
   ```
