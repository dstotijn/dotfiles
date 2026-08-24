---
name: OpenAI Realtime API
description: This skill should be used when the user asks about "OpenAI Realtime API", "realtime voice API", "WebSocket audio streaming", "speech-to-speech with OpenAI", "voice agents with OpenAI", "GPT-4o realtime", "realtime session configuration", "turn detection", "voice activity detection VAD", "realtime audio transcription", "WebRTC OpenAI", or needs to implement real-time audio/voice conversations with OpenAI models.
version: 0.1.0
---

# OpenAI Realtime API

The OpenAI Realtime API enables low-latency, multimodal conversations with GPT-4o class models. It supports speech-to-speech interactions, text input/output, and tool calling over WebSocket, WebRTC, or SIP connections.

## When to Use This Skill

Use this skill when implementing:

- Real-time voice assistants and agents
- Speech-to-speech applications
- Low-latency conversational interfaces
- Audio streaming with GPT-4o models
- Voice-enabled tool calling

## Core Concepts

### Connection Methods

The Realtime API supports three transport protocols:

| Protocol | Use Case | Audio Handling |
|----------|----------|----------------|
| **WebSocket** | Server-to-server applications | Manual (base64 audio events) |
| **WebRTC** | Browser/mobile clients | Automatic (media streams) |
| **SIP** | Telephony integrations | Automatic via SIP trunking |

### Available Models

```typescript
type OpenAIRealtimeModels =
  | 'gpt-realtime'              // Latest stable
  | 'gpt-realtime-mini'         // Faster, lower cost
  | 'gpt-4o-realtime-preview'   // Preview version
  | 'gpt-4o-mini-realtime-preview';
```

### Audio Formats

```typescript
// GA format (recommended)
type RealtimeAudioFormat =
  | { type: 'audio/pcm'; rate: number }  // PCM audio at specified rate
  | { type: 'audio/pcmu' }               // G.711 μ-law (8kHz)
  | { type: 'audio/pcma' };              // G.711 A-law (8kHz)

// Legacy format (deprecated)
type LegacyFormat = 'pcm16' | 'g711_ulaw' | 'g711_alaw';
```

Default: `{ type: 'audio/pcm', rate: 24000 }` (24kHz PCM16).

### Turn Detection (VAD)

Turn detection determines when the user has finished speaking:

```typescript
type TurnDetection = {
  type: 'semantic_vad' | 'server_vad';  // semantic_vad is more intelligent
  createResponse?: boolean;              // Auto-generate response on speech end
  eagerness?: 'auto' | 'low' | 'medium' | 'high';
  interruptResponse?: boolean;           // Allow interruptions
  silenceDurationMs?: number;            // Silence threshold
  threshold?: number;                    // VAD sensitivity (0-1)
};
```

## Session Configuration

Configure the session with these key options:

```typescript
const sessionConfig = {
  model: 'gpt-realtime',
  instructions: 'You are a helpful voice assistant.',
  outputModalities: ['audio'],  // or ['text', 'audio']
  audio: {
    input: {
      format: { type: 'audio/pcm', rate: 24000 },
      transcription: { model: 'gpt-4o-mini-transcribe' },
      turnDetection: { type: 'semantic_vad' },
      noiseReduction: { type: 'near_field' },  // or 'far_field'
    },
    output: {
      format: { type: 'audio/pcm', rate: 24000 },
      voice: 'alloy',  // Voice selection
      speed: 1,        // Playback speed (0.25-4.0)
    },
  },
  tools: [...],  // Function tools or MCP servers
};
```

### Available Voices

`alloy`, `ash`, `ballad`, `coral`, `echo`, `sage`, `shimmer`, `verse`.

## Client Events (Send to Server)

| Event Type | Purpose |
|------------|---------|
| `session.update` | Update session configuration |
| `input_audio_buffer.append` | Send audio data (base64) |
| `input_audio_buffer.commit` | Commit audio buffer (manual VAD) |
| `input_audio_buffer.clear` | Clear audio buffer |
| `conversation.item.create` | Add message/item to conversation |
| `conversation.item.delete` | Remove item from conversation |
| `conversation.item.truncate` | Truncate audio playback |
| `response.create` | Trigger model response |
| `response.cancel` | Cancel ongoing response |

## Server Events (Receive from Server)

| Event Type | Purpose |
|------------|---------|
| `session.created` | Session established |
| `session.updated` | Configuration updated |
| `conversation.item.added` | New item in conversation |
| `conversation.item.done` | Item completed |
| `response.created` | Response started |
| `response.done` | Response completed |
| `response.output_audio.delta` | Audio chunk (base64) |
| `response.output_audio.done` | Audio stream complete |
| `response.output_audio_transcript.delta` | Transcript chunk |
| `input_audio_buffer.speech_started` | User started speaking |
| `input_audio_buffer.speech_stopped` | User stopped speaking |
| `error` | Error occurred |

For complete event schemas, see `references/events.md`.

## Tool Calling

### Function Tools

```typescript
const tool = {
  type: 'function',
  name: 'get_weather',
  description: 'Get current weather for a location',
  parameters: {
    type: 'object',
    properties: {
      location: { type: 'string', description: 'City name' },
    },
    required: ['location'],
  },
};
```

### MCP (Model Context Protocol) Tools

```typescript
const mcpTool = {
  type: 'mcp',
  server_label: 'my-mcp-server',
  server_url: 'https://mcp.example.com',
  allowed_tools: ['tool1', 'tool2'],
  require_approval: 'always',  // 'never' | 'always' | { never: {...}, always: {...} }
};
```

## Implementation Patterns

### WebSocket Connection (Node.js)

```typescript
import WebSocket from 'ws';

const ws = new WebSocket(
  `wss://api.openai.com/v1/realtime?model=gpt-realtime`,
  {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'OpenAI-Beta': 'realtime=v1',
    },
  }
);

ws.on('open', () => {
  // Update session configuration
  ws.send(JSON.stringify({
    type: 'session.update',
    session: {
      instructions: 'You are a helpful assistant.',
      audio: {
        input: { format: { type: 'audio/pcm', rate: 24000 } },
        output: { voice: 'alloy' },
      },
    },
  }));
});

ws.on('message', (data) => {
  const event = JSON.parse(data.toString());
  // Handle events based on event.type
});
```

### Sending Audio

```typescript
// Convert audio to base64 and send
function sendAudio(audioBuffer: ArrayBuffer) {
  const base64 = Buffer.from(audioBuffer).toString('base64');
  ws.send(JSON.stringify({
    type: 'input_audio_buffer.append',
    audio: base64,
  }));
}

// Commit buffer (for manual VAD)
ws.send(JSON.stringify({ type: 'input_audio_buffer.commit' }));
```

### Handling Interruptions

```typescript
ws.on('message', (data) => {
  const event = JSON.parse(data.toString());

  if (event.type === 'input_audio_buffer.speech_started') {
    // User started speaking - interrupt current response
    ws.send(JSON.stringify({ type: 'response.cancel' }));
    ws.send(JSON.stringify({
      type: 'conversation.item.truncate',
      item_id: currentItemId,
      content_index: 0,
      audio_end_ms: elapsedMs,
    }));
  }
});
```

## Using the OpenAI Agents SDK

For TypeScript projects, use the `@openai/agents-realtime` package which provides high-level abstractions.

See `references/agents-sdk.md` for detailed SDK usage patterns.

## Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| `invalid_api_key` | Wrong or missing API key | Verify API key format |
| `session_expired` | Session timed out | Reconnect with new session |
| `rate_limit_exceeded` | Too many requests | Implement backoff strategy |
| `invalid_audio_format` | Wrong audio encoding | Use supported format (PCM16/G.711) |

## Best Practices

1. **Use ephemeral keys in browsers** - Never expose main API keys in client code.
2. **Handle interruptions gracefully** - Truncate audio and cancel responses when user speaks.
3. **Choose appropriate VAD** - Use `semantic_vad` for more natural conversations.
4. **Buffer audio appropriately** - Send audio in reasonable chunks (e.g., 100ms).
5. **Implement reconnection logic** - Handle disconnections gracefully.
6. **Monitor usage** - Track token consumption via `response.done` events.

## Additional Resources

### Reference Files

For detailed information, consult:

- **`references/events.md`** - Complete event schemas and payloads
- **`references/agents-sdk.md`** - OpenAI Agents SDK patterns and examples
- **`references/session-config.md`** - Full session configuration options

### Example Files

Working examples in `examples/`:

- **`websocket-basic.ts`** - Basic WebSocket connection
- **`voice-agent.ts`** - Complete voice agent implementation
