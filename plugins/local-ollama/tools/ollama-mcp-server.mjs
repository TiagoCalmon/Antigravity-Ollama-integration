#!/usr/bin/env node
/**
 * Global Local Ollama MCP Server (Stdio JSON-RPC 2.0)
 * Exposes local Ollama models (qwen2.5-coder:7b-instruct-q3_K_M, gemma4:e4b, gemma4:26b)
 * across all Antigravity workspaces and maintains a persistent cumulative token ledger
 * at ~/.gemini/ollama_usage.json.
 */

import readline from 'node:readline';
import os from 'node:os';
import path from 'node:path';
import { readFile, writeFile, mkdir } from 'node:fs/promises';

const OLLAMA_HOST = process.env.OLLAMA_HOST || 'http://127.0.0.1:11434';
const USAGE_FILE =
  process.env.OLLAMA_USAGE_FILE ||
  path.join(os.homedir(), '.gemini', 'antigravity', 'scratch', 'ollama_usage.json');

const TASK_MODELS = {
  code: 'qwen2.5-coder:7b-instruct-q3_K_M',
  general: 'gemma4:e4b',
  deep: 'gemma4:26b',
};

async function readUsageStats() {
  try {
    const raw = await readFile(USAGE_FILE, 'utf8');
    return JSON.parse(raw);
  } catch {
    return {
      totals: {
        requests: 0,
        prompt_tokens: 0,
        completion_tokens: 0,
        total_tokens: 0,
      },
      by_model: {},
      by_workspace: {},
      last_updated: null,
    };
  }
}

async function recordTokenUsage(model, promptTokens, completionTokens, workspace) {
  const stats = await readUsageStats();
  const pTokens = Number(promptTokens) || 0;
  const cTokens = Number(completionTokens) || 0;
  const tTokens = pTokens + cTokens;
  const wsKey = workspace || process.cwd() || 'global';

  stats.totals.requests = (stats.totals.requests || 0) + 1;
  stats.totals.prompt_tokens = (stats.totals.prompt_tokens || 0) + pTokens;
  stats.totals.completion_tokens = (stats.totals.completion_tokens || 0) + cTokens;
  stats.totals.total_tokens = stats.totals.prompt_tokens + stats.totals.completion_tokens;

  if (!stats.by_model[model]) {
    stats.by_model[model] = {
      requests: 0,
      prompt_tokens: 0,
      completion_tokens: 0,
      total_tokens: 0,
    };
  }
  stats.by_model[model].requests += 1;
  stats.by_model[model].prompt_tokens += pTokens;
  stats.by_model[model].completion_tokens += cTokens;
  stats.by_model[model].total_tokens += tTokens;

  if (!stats.by_workspace) stats.by_workspace = {};
  if (!stats.by_workspace[wsKey]) {
    stats.by_workspace[wsKey] = {
      requests: 0,
      prompt_tokens: 0,
      completion_tokens: 0,
      total_tokens: 0,
    };
  }
  stats.by_workspace[wsKey].requests += 1;
  stats.by_workspace[wsKey].prompt_tokens += pTokens;
  stats.by_workspace[wsKey].completion_tokens += cTokens;
  stats.by_workspace[wsKey].total_tokens += tTokens;

  stats.last_updated = new Date().toISOString();

  await mkdir(path.dirname(USAGE_FILE), { recursive: true });
  await writeFile(USAGE_FILE, JSON.stringify(stats, null, 2), 'utf8');
  return stats;
}

const rl = readline.createInterface({
  input: process.stdin,
  terminal: false,
});

function sendResponse(id, result) {
  process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id, result }) + '\n');
}

function sendError(id, code, message) {
  process.stdout.write(
    JSON.stringify({ jsonrpc: '2.0', id, error: { code, message } }) + '\n'
  );
}

async function handleToolCall(name, args = {}) {
  if (name === 'ollama_status') {
    const [tagsRes, psRes, usageStats] = await Promise.all([
      fetch(`${OLLAMA_HOST}/api/tags`),
      fetch(`${OLLAMA_HOST}/api/ps`),
      readUsageStats(),
    ]);
    const tags = await tagsRes.json();
    const ps = await psRes.json();
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(
            {
              host: OLLAMA_HOST,
              usage_ledger_file: USAGE_FILE,
              cumulative_token_usage: usageStats,
              installed_models: (tags.models || []).map((m) => ({
                name: m.name,
                size_gb: +(m.size / 1e9).toFixed(2),
                quantization: m.details?.quantization_level,
              })),
              running_in_vram: (ps.models || []).map((m) => ({
                name: m.name,
                size_bytes: m.size,
                size_vram_bytes: m.size_vram,
                gpu_offload_percent:
                  m.size > 0 ? +((m.size_vram / m.size) * 100).toFixed(1) : 0,
                context_length: m.context_length,
              })),
            },
            null,
            2
          ),
        },
      ],
    };
  }

  if (name === 'ollama_generate') {
    const task = args.task || 'code';
    const model = args.model || TASK_MODELS[task] || TASK_MODELS.code;
    const num_ctx = args.num_ctx || 4096;
    const res = await fetch(`${OLLAMA_HOST}/api/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        prompt: args.prompt,
        stream: false,
        options: { num_ctx },
      }),
    });
    const data = await res.json();
    const promptTokens = data.prompt_eval_count || 0;
    const evalTokens = data.eval_count || 0;
    const tokPerSec =
      data.eval_duration > 0
        ? +((evalTokens / (data.eval_duration / 1e9)).toFixed(2))
        : 0;

    const stats = await recordTokenUsage(
      data.model || model,
      promptTokens,
      evalTokens,
      args.workspace
    );

    return {
      content: [
        {
          type: 'text',
          text: `[Local Ollama (${data.model} | ${tokPerSec} tok/s | +${promptTokens} in / +${evalTokens} out | Cumulative: ${stats.totals.total_tokens} tokens across ${stats.totals.requests} calls)]\n\n${data.response}`,
        },
      ],
    };
  }

  throw new Error(`Unknown tool: ${name}`);
}

rl.on('line', async (line) => {
  if (!line.trim()) return;
  let req;
  try {
    req = JSON.parse(line);
  } catch {
    return;
  }

  const { id, method, params } = req;

  try {
    if (method === 'initialize') {
      sendResponse(id, {
        protocolVersion: '2024-11-05',
        capabilities: { tools: {} },
        serverInfo: { name: 'local-ollama-mcp', version: '1.1.0' },
      });
    } else if (method === 'notifications/initialized') {
      // No response required for notifications
    } else if (method === 'tools/list') {
      sendResponse(id, {
        tools: [
          {
            name: 'ollama_generate',
            description:
              'Prioritize running coding, drafting, summarization, and reasoning tasks on the local GPU-accelerated Ollama instance and record cumulative token usage.',
            inputSchema: {
              type: 'object',
              properties: {
                prompt: {
                  type: 'string',
                  description: 'Prompt to send to the local Ollama LLM.',
                },
                task: {
                  type: 'string',
                  enum: ['code', 'general', 'deep'],
                  description:
                    'Task routing profile: "code" (qwen2.5-coder:7b-instruct-q3_K_M, 100% GPU), "general" (gemma4:e4b), or "deep" (gemma4:26b MoE).',
                },
                model: {
                  type: 'string',
                  description: 'Optional explicit model override.',
                },
                num_ctx: {
                  type: 'integer',
                  description: 'Context window size (default 4096 for 100% VRAM fit).',
                },
              },
              required: ['prompt'],
            },
          },
          {
            name: 'ollama_status',
            description:
              'Check installed local Ollama models, live GPU VRAM offloading status, and cumulative token usage across all projects.',
            inputSchema: {
              type: 'object',
              properties: {},
            },
          },
        ],
      });
    } else if (method === 'tools/call') {
      const result = await handleToolCall(params.name, params.arguments);
      sendResponse(id, result);
    } else if (id !== undefined) {
      sendResponse(id, {});
    }
  } catch (err) {
    if (id !== undefined) {
      sendError(id, -32000, err.message || String(err));
    }
  }
});
