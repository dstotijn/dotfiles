# OpenAI Realtime API Session Configuration

This document provides comprehensive documentation for session configuration options in the OpenAI Realtime API.

## Configuration Structure

The session configuration is sent via `session.update` events and follows this structure:

```typescript
type SessionConfig = {
  type: 'realtime';
  model?: string;
  instructions?: string;
  output_modalities?: ('text' | 'audio')[];
  audio?: AudioConfig;
  tools?: ToolDefinition[];
  tool_choice?: ToolChoice;
  tracing?: TracingConfig;
  prompt?: PromptConfig;
};
```

## Model Selection

```typescript
// Available models
model: 'gpt-realtime'               // Latest stable (recommended)
     | 'gpt-realtime-mini'          // Faster, lower cost
     | 'gpt-realtime-2025-08-28'    // Dated version
     | 'gpt-realtime-mini-2025-10-06'
     | 'gpt-4o-realtime-preview'    // Preview
     | 'gpt-4o-realtime-preview-2025-06-03'
     | 'gpt-4o-realtime-preview-2024-12-17'
     | 'gpt-4o-realtime-preview-2024-10-01'
     | 'gpt-4o-mini-realtime-preview'
     | 'gpt-4o-mini-realtime-preview-2024-12-17'
```

**Note:** Model cannot be changed after session creation.

## Instructions

System instructions for the model:

```typescript
instructions: string  // Maximum length varies by model
```

Example:

```typescript
instructions: `You are a helpful customer service agent for Acme Corp.
- Be friendly and professional
- If you don't know something, say so
- Always confirm orders before processing`
```

## Output Modalities

Control what types of output the model generates:

```typescript
output_modalities: ('text' | 'audio')[]
```

| Value | Description |
|-------|-------------|
| `['audio']` | Audio only (default) |
| `['text']` | Text only |
| `['text', 'audio']` | Both text and audio |

## Audio Configuration

### Full Audio Config Structure

```typescript
audio: {
  input?: {
    format?: AudioFormat;
    noise_reduction?: NoiseReductionConfig | null;
    transcription?: TranscriptionConfig;
    turn_detection?: TurnDetectionConfig;
  };
  output?: {
    format?: AudioFormat;
    voice?: string;
    speed?: number;
  };
}
```

### Audio Formats

```typescript
// GA format (recommended)
type AudioFormat =
  | { type: 'audio/pcm'; rate: number }  // Linear PCM
  | { type: 'audio/pcmu' }               // G.711 μ-law (8kHz telephony)
  | { type: 'audio/pcma' };              // G.711 A-law (8kHz telephony)

// Legacy format (deprecated)
type LegacyAudioFormat = 'pcm16' | 'g711_ulaw' | 'g711_alaw';
```

**Defaults:**
- Input: `{ type: 'audio/pcm', rate: 24000 }`
- Output: `{ type: 'audio/pcm', rate: 24000 }`

**PCM specifications:**
- Little-endian
- 16-bit signed integers
- Mono channel

### Noise Reduction

```typescript
noise_reduction: {
  type: 'near_field' | 'far_field';
} | null  // null to disable
```

| Type | Use Case |
|------|----------|
| `near_field` | Close microphone (headset, phone) |
| `far_field` | Distant microphone (speaker, room) |
| `null` | Disable noise reduction |

### Transcription Configuration

Configure input audio transcription:

```typescript
transcription: {
  model?: 'gpt-4o-transcribe' | 'gpt-4o-mini-transcribe' | 'whisper-1';
  language?: string;  // ISO 639-1 code (e.g., 'en', 'es', 'ja')
  prompt?: string;    // Context/vocabulary hint for transcription
}
```

**Model comparison:**

| Model | Speed | Quality | Cost |
|-------|-------|---------|------|
| `gpt-4o-transcribe` | Slower | Best | Higher |
| `gpt-4o-mini-transcribe` | Fast | Good | Lower |
| `whisper-1` | Fast | Good | Lowest |

### Turn Detection (VAD)

Voice Activity Detection configuration:

```typescript
turn_detection: {
  type?: 'semantic_vad' | 'server_vad';
  create_response?: boolean;
  eagerness?: 'auto' | 'low' | 'medium' | 'high';
  interrupt_response?: boolean;
  prefix_padding_ms?: number;
  silence_duration_ms?: number;
  threshold?: number;
  idle_timeout_ms?: number;
} | null  // null for manual turn handling
```

**Parameters explained:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `type` | VAD algorithm | `semantic_vad` |
| `create_response` | Auto-trigger response on speech end | `true` |
| `eagerness` | How quickly to detect end of speech | `auto` |
| `interrupt_response` | Allow user to interrupt | `true` |
| `prefix_padding_ms` | Audio to include before speech start | `300` |
| `silence_duration_ms` | Silence duration to trigger end (server_vad) | `500` |
| `threshold` | VAD sensitivity (0.0-1.0) | `0.5` |
| `idle_timeout_ms` | Max silence before ending turn | varies |

**VAD types:**

| Type | Description |
|------|-------------|
| `semantic_vad` | AI-powered, understands natural pauses in speech |
| `server_vad` | Traditional energy-based detection |

**Eagerness levels:**

| Level | Behavior |
|-------|----------|
| `auto` | Adaptive based on context |
| `low` | Wait longer for speech completion |
| `medium` | Balanced response |
| `high` | Respond quickly after any pause |

### Voice Selection

Available voices for audio output:

```typescript
voice: 'alloy' | 'ash' | 'ballad' | 'coral' | 'echo' | 'sage' | 'shimmer' | 'verse'
```

**Voice characteristics:**

| Voice | Style |
|-------|-------|
| `alloy` | Neutral, versatile |
| `ash` | Calm, professional |
| `ballad` | Warm, storytelling |
| `coral` | Friendly, approachable |
| `echo` | Clear, precise |
| `sage` | Thoughtful, measured |
| `shimmer` | Bright, energetic |
| `verse` | Expressive, dynamic |

**Note:** Voice cannot be changed after the model starts speaking.

### Output Speed

Control speech rate:

```typescript
speed: number  // 0.25 to 4.0, default: 1.0
```

| Value | Effect |
|-------|--------|
| `0.25` | Very slow |
| `0.5` | Slow |
| `1.0` | Normal (default) |
| `1.5` | Fast |
| `2.0` | Very fast |
| `4.0` | Maximum speed |

## Tools Configuration

### Function Tools

```typescript
tools: Array<{
  type: 'function';
  name: string;
  description: string;
  parameters: {
    type: 'object';
    properties: Record<string, PropertySchema>;
    required?: string[];
    additionalProperties?: boolean;
  };
}>
```

Example:

```typescript
tools: [
  {
    type: 'function',
    name: 'get_weather',
    description: 'Get current weather for a city',
    parameters: {
      type: 'object',
      properties: {
        location: {
          type: 'string',
          description: 'City name, e.g., "San Francisco"',
        },
        unit: {
          type: 'string',
          enum: ['celsius', 'fahrenheit'],
          description: 'Temperature unit',
        },
      },
      required: ['location'],
    },
  },
]
```

### MCP Tools

```typescript
tools: Array<{
  type: 'mcp';
  server_label: string;
  server_url?: string;
  headers?: Record<string, string>;
  allowed_tools?: string[] | { tool_names?: string[] };
  require_approval?: 'never' | 'always' | {
    never?: { tool_names?: string[] };
    always?: { tool_names?: string[] };
  };
}>
```

Example:

```typescript
tools: [
  {
    type: 'mcp',
    server_label: 'database',
    server_url: 'https://mcp.example.com/db',
    headers: { 'X-API-Key': 'secret' },
    allowed_tools: ['query', 'list_tables'],
    require_approval: {
      always: { tool_names: ['delete', 'update'] },
      never: { tool_names: ['query', 'list_tables'] },
    },
  },
]
```

## Tool Choice

Control how the model uses tools:

```typescript
tool_choice: 'auto' | 'none' | 'required' | { type: 'function'; name: string }
```

| Value | Behavior |
|-------|----------|
| `'auto'` | Model decides whether to use tools |
| `'none'` | Never use tools |
| `'required'` | Must use at least one tool |
| `{ type: 'function', name: '...' }` | Must use specific tool |

## Tracing Configuration

Enable observability and debugging:

```typescript
tracing: 'auto' | {
  workflow_name?: string;
  group_id?: string;
  metadata?: Record<string, any>;
} | null
```

| Value | Behavior |
|-------|----------|
| `'auto'` | Enable with default settings |
| `{ ... }` | Enable with custom settings |
| `null` | Disable tracing |

Example:

```typescript
tracing: {
  workflow_name: 'customer-support',
  group_id: 'session-123',
  metadata: {
    user_id: 'user-456',
    channel: 'phone',
  },
}
```

**Note:** Tracing configuration cannot be changed after session creation.

## Prompt Configuration

Use stored prompts:

```typescript
prompt: {
  id: string;      // Prompt ID
  version?: string; // Specific version
  variables?: Record<string, string>;
}
```

## Default Configuration

The default session configuration used by the Agents SDK:

```typescript
const DEFAULT_CONFIG = {
  outputModalities: ['audio'],
  audio: {
    input: {
      format: { type: 'audio/pcm', rate: 24000 },
      transcription: { model: 'gpt-4o-mini-transcribe' },
      turnDetection: { type: 'semantic_vad' },
      noiseReduction: null,
    },
    output: {
      format: { type: 'audio/pcm', rate: 24000 },
      speed: 1,
    },
  },
};
```

## Configuration Examples

### Voice Assistant (Default)

```typescript
{
  instructions: 'You are a helpful voice assistant.',
  output_modalities: ['audio'],
  audio: {
    input: {
      format: { type: 'audio/pcm', rate: 24000 },
      transcription: { model: 'gpt-4o-mini-transcribe' },
      turn_detection: { type: 'semantic_vad' },
    },
    output: {
      format: { type: 'audio/pcm', rate: 24000 },
      voice: 'alloy',
    },
  },
}
```

### Telephony (Twilio/SIP)

```typescript
{
  instructions: 'You are a phone support agent.',
  output_modalities: ['audio'],
  audio: {
    input: {
      format: { type: 'audio/pcmu' },  // G.711 μ-law
      noise_reduction: { type: 'far_field' },
      turn_detection: {
        type: 'semantic_vad',
        eagerness: 'low',  // Don't interrupt as quickly
      },
    },
    output: {
      format: { type: 'audio/pcmu' },
      voice: 'coral',
      speed: 0.9,  // Slightly slower for clarity
    },
  },
}
```

### Text + Audio Hybrid

```typescript
{
  instructions: 'Respond with both text and speech.',
  output_modalities: ['text', 'audio'],
  audio: {
    input: {
      transcription: { model: 'gpt-4o-transcribe' },
    },
    output: {
      voice: 'sage',
    },
  },
}
```

### Manual Turn Detection

```typescript
{
  instructions: 'Wait for explicit user input.',
  audio: {
    input: {
      turn_detection: null,  // Disable auto-detection
    },
  },
}
// Client must call input_audio_buffer.commit to trigger responses
```

### High-Quality Transcription

```typescript
{
  audio: {
    input: {
      format: { type: 'audio/pcm', rate: 48000 },  // Higher sample rate
      transcription: {
        model: 'gpt-4o-transcribe',
        language: 'en',
        prompt: 'Technical discussion about software architecture.',
      },
      noise_reduction: { type: 'near_field' },
    },
  },
}
```

### Fast Response Mode

```typescript
{
  audio: {
    input: {
      turn_detection: {
        type: 'server_vad',
        eagerness: 'high',
        silence_duration_ms: 300,
      },
    },
    output: {
      speed: 1.2,
    },
  },
}
```

## Updating Configuration

Configuration can be updated mid-session (except for locked fields):

```typescript
// Via WebSocket
ws.send(JSON.stringify({
  type: 'session.update',
  session: {
    instructions: 'Updated instructions.',
    audio: {
      output: {
        speed: 1.5,
      },
    },
  },
}));
```

**Fields that CANNOT be changed after session start:**
- `model`
- `voice` (after first audio output)
- `tracing` (after initial configuration)

**Fields that CAN be changed:**
- `instructions`
- `tools` and `tool_choice`
- `output_modalities`
- Audio formats
- Turn detection settings
- Transcription settings
- Noise reduction
- Output speed
