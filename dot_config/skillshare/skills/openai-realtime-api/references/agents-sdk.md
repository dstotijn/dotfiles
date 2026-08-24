# OpenAI Agents SDK for Realtime

The `@openai/agents-realtime` package provides high-level abstractions for building voice agents with the OpenAI Realtime API. It handles connection management, audio buffering, tool execution, agent handoffs, and history management.

## Installation

```bash
npm install @openai/agents-realtime
# or
pnpm add @openai/agents-realtime
```

## Core Components

### RealtimeAgent

A specialized agent for voice conversations. Unlike text agents, RealtimeAgents:

- Cannot change models mid-conversation
- Do not support structured outputs
- Support voice configuration (though voice cannot change after first speech)

```typescript
import { RealtimeAgent } from '@openai/agents-realtime';

const agent = new RealtimeAgent({
  name: 'my-assistant',
  instructions: 'You are a helpful voice assistant.',
  voice: 'alloy',  // Optional: default voice
  tools: [...],    // Optional: function tools
  handoffs: [...], // Optional: other RealtimeAgents to hand off to
});
```

### RealtimeSession

The main orchestrator for voice conversations. Manages:

- Transport layer (WebSocket or WebRTC)
- Tool execution
- Agent handoffs
- Conversation history
- Output guardrails

```typescript
import { RealtimeSession, RealtimeAgent } from '@openai/agents-realtime';

const agent = new RealtimeAgent({
  name: 'assistant',
  instructions: 'You are a helpful assistant.',
});

const session = new RealtimeSession(agent, {
  apiKey: process.env.OPENAI_API_KEY,
  transport: 'websocket',  // or 'webrtc'
  model: 'gpt-realtime',
});

// Connect to the API
await session.connect({
  apiKey: process.env.OPENAI_API_KEY,
});
```

## Session Options

```typescript
type RealtimeSessionOptions = {
  // API key (string or async function)
  apiKey: string | (() => string | Promise<string>);

  // Transport: 'webrtc', 'websocket', or custom transport
  transport: 'webrtc' | 'websocket' | RealtimeTransportLayer;

  // Model to use
  model?: 'gpt-realtime' | 'gpt-realtime-mini' | string;

  // Additional context passed to agent
  context?: TContext;

  // Output guardrails
  outputGuardrails?: RealtimeOutputGuardrail[];
  outputGuardrailSettings?: RealtimeOutputGuardrailSettings;

  // Session configuration overrides
  config?: Partial<RealtimeSessionConfig>;

  // Store audio in history (default: false to save memory)
  historyStoreAudio?: boolean;

  // Tracing options
  tracingDisabled?: boolean;
  groupId?: string;
  traceMetadata?: Record<string, any>;
  workflowName?: string;

  // MCP tool handling
  automaticallyTriggerResponseForMcpToolCalls?: boolean;
};
```

## Session Configuration

```typescript
const session = new RealtimeSession(agent, {
  config: {
    outputModalities: ['audio'],  // or ['text', 'audio']
    audio: {
      input: {
        format: { type: 'audio/pcm', rate: 24000 },
        transcription: { model: 'gpt-4o-mini-transcribe' },
        turnDetection: {
          type: 'semantic_vad',
          eagerness: 'medium',
          interruptResponse: true,
        },
        noiseReduction: { type: 'near_field' },
      },
      output: {
        format: { type: 'audio/pcm', rate: 24000 },
        voice: 'alloy',
        speed: 1,
      },
    },
  },
});
```

## Event Handling

The session emits various events for monitoring and control:

```typescript
// Agent lifecycle events
session.on('agent_start', (context, agent) => {
  console.log(`Agent ${agent.name} started`);
});

session.on('agent_end', (context, agent, output) => {
  console.log(`Agent ${agent.name} finished: ${output}`);
});

session.on('agent_handoff', (context, fromAgent, toAgent) => {
  console.log(`Handoff from ${fromAgent.name} to ${toAgent.name}`);
});

// Audio events
session.on('audio_start', (context, agent) => {
  console.log('Audio output started');
});

session.on('audio', (event) => {
  // event.data: ArrayBuffer of audio
  // event.responseId: string
  playAudio(event.data);
});

session.on('audio_stopped', (context, agent) => {
  console.log('Audio output stopped');
});

session.on('audio_interrupted', (context, agent) => {
  console.log('Audio was interrupted');
});

// Tool events
session.on('agent_tool_start', (context, agent, tool, { toolCall }) => {
  console.log(`Calling tool: ${tool.name}`);
});

session.on('agent_tool_end', (context, agent, tool, result, { toolCall }) => {
  console.log(`Tool result: ${result}`);
});

// Tool approval events
session.on('tool_approval_requested', (context, agent, request) => {
  // Handle approval UI
  if (request.type === 'function_approval') {
    // request.tool, request.approvalItem
  } else if (request.type === 'mcp_approval_request') {
    // request.approvalItem
  }
});

// History events
session.on('history_updated', (history) => {
  console.log('History changed:', history);
});

session.on('history_added', (item) => {
  console.log('New item:', item);
});

// Guardrail events
session.on('guardrail_tripped', (context, agent, error, { itemId }) => {
  console.log('Guardrail triggered:', error.message);
});

// Transport events (raw API events)
session.on('transport_event', (event) => {
  console.log('Raw event:', event.type);
});

// Error handling
session.on('error', (error) => {
  console.error('Session error:', error);
});
```

## Sending Messages

```typescript
// Send text message
session.sendMessage('Hello, how can I help you?');

// Send structured message with images
session.sendMessage({
  type: 'message',
  role: 'user',
  content: [
    { type: 'input_text', text: 'What is in this image?' },
    { type: 'input_image', image: 'data:image/png;base64,...' },
  ],
});

// Add image only
session.addImage('data:image/png;base64,...', { triggerResponse: true });
```

## Sending Audio

```typescript
// Send audio buffer (WebSocket transport)
session.sendAudio(audioBuffer);

// Send audio and commit (for manual VAD)
session.sendAudio(audioBuffer, { commit: true });
```

## Interruption Handling

```typescript
// Manually interrupt (e.g., from a "stop" button)
session.interrupt();
```

## Tool Approval

```typescript
session.on('tool_approval_requested', async (context, agent, request) => {
  const approved = await showApprovalDialog(request);

  if (approved) {
    await session.approve(request.approvalItem, { alwaysApprove: false });
  } else {
    await session.reject(request.approvalItem, { alwaysReject: false });
  }
});
```

## Agent Handoffs

```typescript
const supportAgent = new RealtimeAgent({
  name: 'support',
  instructions: 'You handle customer support inquiries.',
});

const salesAgent = new RealtimeAgent({
  name: 'sales',
  instructions: 'You handle sales inquiries.',
  handoffs: [supportAgent],  // Can hand off to support
});

const triageAgent = new RealtimeAgent({
  name: 'triage',
  instructions: 'Route users to the appropriate department.',
  handoffs: [supportAgent, salesAgent],
});

const session = new RealtimeSession(triageAgent);
```

## Defining Tools

```typescript
import { tool } from '@openai/agents-core';
import { z } from 'zod';

const weatherTool = tool({
  name: 'get_weather',
  description: 'Get weather for a location',
  parameters: z.object({
    location: z.string().describe('City name'),
    unit: z.enum(['celsius', 'fahrenheit']).optional(),
  }),
  execute: async (args) => {
    const weather = await fetchWeather(args.location, args.unit);
    return JSON.stringify(weather);
  },
});

// Tool with approval requirement
const dangerousTool = tool({
  name: 'delete_file',
  description: 'Delete a file',
  parameters: z.object({ path: z.string() }),
  needsApproval: true,  // Always requires approval
  execute: async (args) => {
    await deleteFile(args.path);
    return 'File deleted';
  },
});

const agent = new RealtimeAgent({
  name: 'assistant',
  instructions: '...',
  tools: [weatherTool, dangerousTool],
});
```

## Background Tools

Tools can return results without triggering a new response:

```typescript
import { backgroundResult } from '@openai/agents-realtime';

const loggingTool = tool({
  name: 'log_event',
  description: 'Log an event',
  parameters: z.object({ event: z.string() }),
  execute: async (args) => {
    await logEvent(args.event);
    // Return background result - no new response generated
    return backgroundResult('Event logged');
  },
});
```

## MCP Server Integration

```typescript
const agent = new RealtimeAgent({
  name: 'assistant',
  instructions: '...',
  mcpServers: [
    {
      type: 'mcp',
      server_label: 'file-system',
      server_url: 'https://mcp.example.com/fs',
      allowed_tools: ['read_file', 'list_directory'],
      require_approval: {
        always: { tool_names: ['write_file', 'delete_file'] },
        never: { tool_names: ['read_file'] },
      },
    },
  ],
});

// Listen for MCP tool availability
session.on('mcp_tools_changed', (tools) => {
  console.log('Available MCP tools:', tools.map(t => t.name));
});

// Access current MCP tools
const tools = session.availableMcpTools;
```

## Output Guardrails

```typescript
import { defineRealtimeOutputGuardrail } from '@openai/agents-realtime';

const profanityGuardrail = defineRealtimeOutputGuardrail({
  name: 'profanity_filter',
  execute: async ({ agentOutput }) => {
    const hasProfanity = checkProfanity(agentOutput);
    return {
      tripwireTriggered: hasProfanity,
      outputInfo: hasProfanity ? { reason: 'Contains profanity' } : null,
    };
  },
});

const session = new RealtimeSession(agent, {
  outputGuardrails: [profanityGuardrail],
  outputGuardrailSettings: {
    debounceTextLength: 50,  // Check every 50 characters
  },
});
```

## History Management

```typescript
// Get current history
const history = session.history;

// Update history
session.updateHistory((currentHistory) => {
  // Filter out certain items
  return currentHistory.filter(item => item.role !== 'system');
});

// Replace history entirely
session.updateHistory([
  {
    itemId: 'custom-1',
    type: 'message',
    role: 'user',
    status: 'completed',
    content: [{ type: 'input_text', text: 'Start fresh' }],
  },
]);
```

## Context Management

```typescript
type MyContext = {
  userId: string;
  preferences: UserPreferences;
};

const session = new RealtimeSession<MyContext>(agent, {
  context: {
    userId: 'user-123',
    preferences: userPrefs,
  },
});

// Access in tools
const myTool = tool({
  name: 'get_user_data',
  execute: async (args, { context }) => {
    // context.history - conversation history
    // context.userId - custom context
    return getUserData(context.userId);
  },
});
```

## Muting

```typescript
// Check mute status (null if transport doesn't support)
const isMuted = session.muted;

// Mute/unmute (WebRTC only)
session.mute(true);
session.mute(false);
```

## Token Usage

```typescript
// Get cumulative usage
const usage = session.usage;
console.log(`Input tokens: ${usage.inputTokens}`);
console.log(`Output tokens: ${usage.outputTokens}`);
console.log(`Total tokens: ${usage.totalTokens}`);
```

## Closing the Session

```typescript
// Disconnect gracefully
session.close();
```

## Transport Layer Access

For advanced use cases, access the underlying transport:

```typescript
const transport = session.transport;

// Send raw events
transport.sendEvent({
  type: 'response.create',
  response: {
    modalities: ['text'],
  },
});

// Listen to raw events
transport.on('*', (event) => {
  console.log('Raw event:', event);
});
```

## Static Helper Methods

```typescript
// Compute session config without connecting
const config = await RealtimeSession.computeInitialSessionConfig(
  agent,
  sessionOptions,
  overrides
);
```

## Error Handling

```typescript
import { ModelBehaviorError, UserError } from '@openai/agents-core';

session.on('error', (error) => {
  if (error.error instanceof ModelBehaviorError) {
    console.error('Model error:', error.error.message);
  } else if (error.error instanceof UserError) {
    console.error('User error:', error.error.message);
  } else {
    console.error('Unknown error:', error);
  }
});
```

## WebRTC Transport (Browser)

In browser environments with WebRTC support:

```typescript
const session = new RealtimeSession(agent, {
  transport: 'webrtc',  // Automatic in browsers
});

// WebRTC handles audio I/O automatically
await session.connect({
  apiKey: ephemeralKey,  // Use ephemeral key in browsers
});
```

## Custom Transport Layer

```typescript
import { RealtimeTransportLayer } from '@openai/agents-realtime';

class CustomTransport implements RealtimeTransportLayer {
  // Implement required methods
  async connect(options) { ... }
  sendEvent(event) { ... }
  sendAudio(audio, options) { ... }
  mute(muted) { ... }
  interrupt() { ... }
  close() { ... }
  // ... etc
}

const session = new RealtimeSession(agent, {
  transport: new CustomTransport(),
});
```

## Twilio Integration

For telephony via Twilio, use the `TwilioRealtimeTransportLayer`:

```typescript
import { TwilioRealtimeTransportLayer } from '@openai/agents-realtime/twilio';

const transport = new TwilioRealtimeTransportLayer({
  // Twilio-specific options
});

const session = new RealtimeSession(agent, {
  transport,
  config: {
    audio: {
      input: { format: { type: 'audio/pcmu' } },  // G.711 μ-law
      output: { format: { type: 'audio/pcmu' } },
    },
  },
});
```
