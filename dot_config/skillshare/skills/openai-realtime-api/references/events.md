# OpenAI Realtime API Events Reference

This document provides comprehensive documentation for all client and server events in the OpenAI Realtime API.

## Client Events (Send to Server)

### Session Events

#### `session.update`

Update the session configuration. Can be sent at any time during the session.

```typescript
{
  type: 'session.update',
  event_id?: string,
  session: {
    type: 'realtime',
    instructions?: string,
    model?: string,
    output_modalities?: ('text' | 'audio')[],
    audio?: {
      input?: {
        format?: { type: 'audio/pcm', rate: number } | { type: 'audio/pcmu' } | { type: 'audio/pcma' },
        noise_reduction?: { type: 'near_field' | 'far_field' } | null,
        transcription?: {
          model?: 'gpt-4o-transcribe' | 'gpt-4o-mini-transcribe' | 'whisper-1',
          language?: string,
          prompt?: string,
        },
        turn_detection?: {
          type?: 'semantic_vad' | 'server_vad',
          create_response?: boolean,
          eagerness?: 'auto' | 'low' | 'medium' | 'high',
          interrupt_response?: boolean,
          prefix_padding_ms?: number,
          silence_duration_ms?: number,
          threshold?: number,
          idle_timeout_ms?: number,
        },
      },
      output?: {
        format?: { type: 'audio/pcm', rate: number } | { type: 'audio/pcmu' } | { type: 'audio/pcma' },
        voice?: string,
        speed?: number,
      },
    },
    tools?: ToolDefinition[],
    tool_choice?: 'auto' | 'none' | 'required' | { type: 'function', name: string },
    tracing?: 'auto' | { workflow_name?: string, group_id?: string, metadata?: Record<string, any> } | null,
  },
}
```

### Input Audio Buffer Events

#### `input_audio_buffer.append`

Append audio data to the input buffer. Audio must be base64-encoded.

```typescript
{
  type: 'input_audio_buffer.append',
  event_id?: string,
  audio: string,  // base64-encoded audio
}
```

#### `input_audio_buffer.commit`

Commit the current audio buffer. Required when turn detection is disabled (manual mode).

```typescript
{
  type: 'input_audio_buffer.commit',
  event_id?: string,
}
```

#### `input_audio_buffer.clear`

Clear the current audio buffer without committing.

```typescript
{
  type: 'input_audio_buffer.clear',
  event_id?: string,
}
```

### Conversation Item Events

#### `conversation.item.create`

Create a new item in the conversation.

```typescript
{
  type: 'conversation.item.create',
  event_id?: string,
  previous_item_id?: string | null,
  item: {
    type: 'message' | 'function_call_output',
    // For message type:
    role?: 'user' | 'assistant' | 'system',
    content?: ContentPart[],
    // For function_call_output type:
    call_id?: string,
    output?: string,
  },
}
```

Content parts for messages:

```typescript
type ContentPart =
  | { type: 'input_text', text: string }
  | { type: 'input_audio', audio?: string, transcript?: string }
  | { type: 'input_image', image_url: string }
  | { type: 'output_text', text: string }
  | { type: 'output_audio', audio?: string, transcript?: string };
```

#### `conversation.item.delete`

Delete an item from the conversation.

```typescript
{
  type: 'conversation.item.delete',
  event_id?: string,
  item_id: string,
}
```

#### `conversation.item.truncate`

Truncate audio content of an item. Used when interrupting playback.

```typescript
{
  type: 'conversation.item.truncate',
  event_id?: string,
  item_id: string,
  content_index: number,
  audio_end_ms: number,
}
```

#### `conversation.item.retrieve`

Retrieve the full content of an item.

```typescript
{
  type: 'conversation.item.retrieve',
  event_id?: string,
  item_id: string,
}
```

### Response Events

#### `response.create`

Trigger the model to generate a response.

```typescript
{
  type: 'response.create',
  event_id?: string,
  response?: {
    // Optional response configuration
    modalities?: ('text' | 'audio')[],
    instructions?: string,
    voice?: string,
    output_audio_format?: AudioFormat,
    tools?: ToolDefinition[],
    tool_choice?: ToolChoice,
    max_output_tokens?: number | 'inf',
    metadata?: Record<string, any>,
  },
}
```

#### `response.cancel`

Cancel the current response.

```typescript
{
  type: 'response.cancel',
  event_id?: string,
  response_id?: string,
}
```

---

## Server Events (Receive from Server)

### Session Events

#### `session.created`

Emitted when the session is first established.

```typescript
{
  type: 'session.created',
  event_id: string,
  session: SessionObject,
}
```

#### `session.updated`

Emitted when session configuration is updated.

```typescript
{
  type: 'session.updated',
  event_id: string,
  session: SessionObject,
}
```

### Conversation Events

#### `conversation.created`

Emitted when a new conversation is created.

```typescript
{
  type: 'conversation.created',
  event_id: string,
  conversation: {
    id?: string,
    object?: 'realtime.conversation',
  },
}
```

#### `conversation.item.added`

Emitted when a new item is added to the conversation.

```typescript
{
  type: 'conversation.item.added',
  event_id: string,
  item: ConversationItem,
  previous_item_id?: string | null,
}
```

#### `conversation.item.done`

Emitted when an item is completed.

```typescript
{
  type: 'conversation.item.done',
  event_id: string,
  item: ConversationItem,
  previous_item_id?: string | null,
}
```

#### `conversation.item.deleted`

Emitted when an item is deleted.

```typescript
{
  type: 'conversation.item.deleted',
  event_id: string,
  item_id: string,
}
```

#### `conversation.item.truncated`

Emitted when an item's audio is truncated.

```typescript
{
  type: 'conversation.item.truncated',
  event_id: string,
  item_id: string,
  content_index: number,
  audio_end_ms: number,
}
```

#### `conversation.item.retrieved`

Emitted in response to a retrieve request.

```typescript
{
  type: 'conversation.item.retrieved',
  event_id: string,
  item: ConversationItem,
}
```

### Input Audio Buffer Events

#### `input_audio_buffer.committed`

Emitted when audio buffer is committed.

```typescript
{
  type: 'input_audio_buffer.committed',
  event_id: string,
  item_id: string,
  previous_item_id?: string | null,
}
```

#### `input_audio_buffer.cleared`

Emitted when audio buffer is cleared.

```typescript
{
  type: 'input_audio_buffer.cleared',
  event_id: string,
}
```

#### `input_audio_buffer.speech_started`

Emitted when VAD detects speech start.

```typescript
{
  type: 'input_audio_buffer.speech_started',
  event_id: string,
  item_id: string,
  audio_start_ms: number,
}
```

#### `input_audio_buffer.speech_stopped`

Emitted when VAD detects speech end.

```typescript
{
  type: 'input_audio_buffer.speech_stopped',
  event_id: string,
  item_id: string,
  audio_end_ms: number,
}
```

### Transcription Events

#### `conversation.item.input_audio_transcription.completed`

Emitted when user audio transcription completes.

```typescript
{
  type: 'conversation.item.input_audio_transcription.completed',
  event_id: string,
  item_id: string,
  content_index: number,
  transcript: string,
  logprobs?: any[] | null,
  usage?: {
    type: 'tokens',
    total_tokens: number,
    input_tokens: number,
    input_token_details: {
      text_tokens: number,
      audio_tokens: number,
    },
    output_tokens: number,
  },
}
```

#### `conversation.item.input_audio_transcription.delta`

Emitted for streaming transcription updates.

```typescript
{
  type: 'conversation.item.input_audio_transcription.delta',
  event_id: string,
  item_id: string,
  content_index?: number,
  delta?: string,
  logprobs?: any[] | null,
}
```

#### `conversation.item.input_audio_transcription.failed`

Emitted when transcription fails.

```typescript
{
  type: 'conversation.item.input_audio_transcription.failed',
  event_id: string,
  item_id: string,
  content_index: number,
  error: {
    code?: string,
    message?: string,
    param?: string,
    type?: string,
  },
}
```

### Response Events

#### `response.created`

Emitted when a response starts.

```typescript
{
  type: 'response.created',
  event_id: string,
  response: ResponseObject,
}
```

#### `response.done`

Emitted when a response completes.

```typescript
{
  type: 'response.done',
  event_id: string,
  response: {
    id?: string,
    conversation_id?: string,
    status?: 'completed' | 'incomplete' | 'failed' | 'cancelled' | 'in_progress',
    status_details?: Record<string, any>,
    output?: ConversationItem[],
    usage?: {
      input_tokens?: number,
      input_token_details?: Record<string, any>,
      output_tokens?: number,
      output_token_details?: Record<string, any>,
    },
  },
}
```

#### `response.output_item.added`

Emitted when an output item is added to the response.

```typescript
{
  type: 'response.output_item.added',
  event_id: string,
  item: ConversationItem,
  output_index: number,
  response_id: string,
}
```

#### `response.output_item.done`

Emitted when an output item completes.

```typescript
{
  type: 'response.output_item.done',
  event_id: string,
  item: ConversationItem,
  output_index: number,
  response_id: string,
}
```

### Audio Output Events

#### `response.output_audio.delta`

Emitted for audio output chunks (base64-encoded).

```typescript
{
  type: 'response.output_audio.delta',
  event_id: string,
  item_id: string,
  content_index: number,
  delta: string,  // base64-encoded audio
  output_index: number,
  response_id: string,
}
```

#### `response.output_audio.done`

Emitted when audio output completes.

```typescript
{
  type: 'response.output_audio.done',
  event_id: string,
  item_id: string,
  content_index: number,
  output_index: number,
  response_id: string,
}
```

#### `response.output_audio_transcript.delta`

Emitted for audio transcript chunks.

```typescript
{
  type: 'response.output_audio_transcript.delta',
  event_id: string,
  item_id: string,
  content_index: number,
  delta: string,
  output_index: number,
  response_id: string,
}
```

#### `response.output_audio_transcript.done`

Emitted when audio transcript completes.

```typescript
{
  type: 'response.output_audio_transcript.done',
  event_id: string,
  item_id: string,
  content_index: number,
  transcript: string,
  output_index: number,
  response_id: string,
}
```

### Text Output Events

#### `response.output_text.delta`

Emitted for text output chunks.

```typescript
{
  type: 'response.output_text.delta',
  event_id: string,
  item_id: string,
  content_index: number,
  delta: string,
  output_index: number,
  response_id: string,
}
```

#### `response.output_text.done`

Emitted when text output completes.

```typescript
{
  type: 'response.output_text.done',
  event_id: string,
  item_id: string,
  content_index: number,
  text: string,
  output_index: number,
  response_id: string,
}
```

### Function Call Events

#### `response.function_call_arguments.delta`

Emitted for function call argument chunks.

```typescript
{
  type: 'response.function_call_arguments.delta',
  event_id: string,
  item_id: string,
  call_id: string,
  delta: string,
  output_index: number,
  response_id: string,
}
```

#### `response.function_call_arguments.done`

Emitted when function call arguments complete.

```typescript
{
  type: 'response.function_call_arguments.done',
  event_id: string,
  item_id: string,
  call_id: string,
  arguments: string,
  output_index: number,
  response_id: string,
}
```

### Content Part Events

#### `response.content_part.added`

Emitted when a content part is added.

```typescript
{
  type: 'response.content_part.added',
  event_id: string,
  item_id: string,
  content_index: number,
  output_index: number,
  response_id: string,
  part: {
    type?: 'text' | 'audio',
    text?: string,
    audio?: string,
    transcript?: string,
  },
}
```

#### `response.content_part.done`

Emitted when a content part completes.

```typescript
{
  type: 'response.content_part.done',
  event_id: string,
  item_id: string,
  content_index: number,
  output_index: number,
  response_id: string,
  part: ContentPart,
}
```

### Rate Limit Events

#### `rate_limits.updated`

Emitted when rate limits are updated.

```typescript
{
  type: 'rate_limits.updated',
  event_id: string,
  rate_limits: Array<{
    name?: 'requests' | 'tokens',
    limit?: number,
    remaining?: number,
    reset_seconds?: number,
  }>,
}
```

### Error Events

#### `error`

Emitted when an error occurs.

```typescript
{
  type: 'error',
  event_id?: string,
  error: {
    type?: string,
    code?: string,
    message?: string,
    param?: string,
    event_id?: string,
  },
}
```

### MCP Events

#### `mcp_list_tools.in_progress`

Emitted when MCP tool listing starts.

```typescript
{
  type: 'mcp_list_tools.in_progress',
  event_id?: string,
  item_id?: string,
}
```

#### `mcp_list_tools.completed`

Emitted when MCP tool listing completes.

```typescript
{
  type: 'mcp_list_tools.completed',
  event_id?: string,
  item_id?: string,
}
```

#### `mcp_list_tools.failed`

Emitted when MCP tool listing fails.

```typescript
{
  type: 'mcp_list_tools.failed',
  event_id?: string,
  item_id?: string,
}
```

#### `response.mcp_call.in_progress`

Emitted when an MCP call starts.

```typescript
{
  type: 'response.mcp_call.in_progress',
  event_id: string,
  item_id: string,
  output_index: number,
}
```

#### `response.mcp_call.completed`

Emitted when an MCP call completes.

```typescript
{
  type: 'response.mcp_call.completed',
  event_id: string,
  item_id: string,
  output_index: number,
}
```

#### `response.mcp_call_arguments.delta`

Emitted for MCP call argument chunks.

```typescript
{
  type: 'response.mcp_call_arguments.delta',
  event_id: string,
  response_id: string,
  item_id: string,
  output_index: number,
  delta: string,
  obfuscation: string,
}
```

#### `response.mcp_call_arguments.done`

Emitted when MCP call arguments complete.

```typescript
{
  type: 'response.mcp_call_arguments.done',
  event_id: string,
  response_id: string,
  item_id: string,
  output_index: number,
  arguments: string,
}
```

---

## Conversation Item Types

```typescript
type ConversationItem = {
  id?: string,
  type: 'message' | 'function_call' | 'function_call_output' | 'mcp_call' | 'mcp_tool_call' | 'mcp_approval_request' | 'mcp_approval_response' | 'mcp_list_tools',
  status?: 'completed' | 'incomplete' | 'in_progress',
  role?: 'user' | 'assistant' | 'system',
  content?: ContentPart[],
  // Function call fields
  name?: string,
  call_id?: string,
  arguments?: string,
  output?: string,
  // MCP fields
  server_label?: string,
  tools?: McpTool[],
  approval_request_id?: string,
  approve?: boolean,
  reason?: string,
  error?: any,
};
```
