#!/usr/bin/env node
/**
 * Tiny local MCP server for the workshop.
 * Spawned by Promptfoo via stdio (command/args) — not an HTTP server.
 *
 * Tools:
 *   echo                 — happy-path string return
 *   add                  — deterministic math
 *   read_workspace_file  — reads only files in this folder; blocks path traversal
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';

const serverDir = path.dirname(fileURLToPath(import.meta.url));

const server = new McpServer({
  name: 'workshop-local-mcp',
  version: '1.0.0',
});

server.registerTool(
  'echo',
  {
    title: 'Echo',
    description: 'Return the input text unchanged',
    inputSchema: {
      text: z.string().describe('Text to echo'),
    },
  },
  async (args) => ({
    content: [{ type: 'text', text: String(args.text) }],
  }),
);

server.registerTool(
  'add',
  {
    title: 'Add',
    description: 'Add two numbers and return the sum',
    inputSchema: {
      a: z.number().describe('First addend'),
      b: z.number().describe('Second addend'),
    },
  },
  async (args) => ({
    content: [{ type: 'text', text: String(args.a + args.b) }],
  }),
);

server.registerTool(
  'read_workspace_file',
  {
    title: 'Read workspace file',
    description:
      'Read a file from the lesson folder only. Paths with .. or absolute system paths are rejected.',
    inputSchema: {
      name: z.string().describe('Basename or relative path under the lesson folder'),
    },
  },
  async (args) => {
    const requested = String(args.name);
    if (requested.includes('..') || requested.includes('~') || path.isAbsolute(requested)) {
      return {
        content: [
          {
            type: 'text',
            text: 'Error: Path traversal not allowed',
          },
        ],
        isError: true,
      };
    }

    const resolved = path.resolve(serverDir, requested);
    if (!resolved.startsWith(serverDir + path.sep) && resolved !== serverDir) {
      return {
        content: [{ type: 'text', text: 'Error: Path traversal not allowed' }],
        isError: true,
      };
    }

    try {
      const text = fs.readFileSync(resolved, 'utf8');
      return { content: [{ type: 'text', text }] };
    } catch (error) {
      return {
        content: [{ type: 'text', text: `Error: ${error.message}` }],
        isError: true,
      };
    }
  },
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('workshop-local-mcp listening on stdio');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
