# Message Types

The Gemini Live API uses a bidirectional WebSocket protocol with distinct client and server message types. Each message must contain exactly one primary field.

## Client Messages

### BidiGenerateContentSetup

Initial session configuration sent as the first message after WebSocket connection.

```json
{
  "model": "string",
  "generationConfig": {
    "candidateCount": 1,
    "maxOutputTokens": 8192,
    "temperature": 1.0,
    "topP": 0.95,
    "topK": 40,
    "presencePenalty": 0.0,
    "frequencyPenalty": 0.0,
    "responseModalities": ["TEXT"],
    "speechConfig": {
      "voiceConfig": {
        "prebuiltVoiceConfig": {
          "voiceName": "Puck"
        }
      },
      "languageCode": "en-US"
    },
    "mediaResolution": "object"
  },
  "systemInstruction": "string",
  "tools": []
}
```

**Unsupported fields**: `responseLogprobs`, `responseMimeType`, `logprobs`, `responseSchema`, `stopSequence`, `routingConfig`, `audioTimestamp`.

### BidiGenerateContentClientContent

Incremental content update for the current conversation. Sending this message interrupts any ongoing model generation.

```json
{
  "turns": [
    {
      "role": "user",
      "parts": [
        {
          "text": "Hello, how are you?"
        }
      ]
    }
  ],
  "turnComplete": true
}
```

| Field | Type | Description |
|-------|------|-------------|
| `turns` | array | Array of Content objects representing conversation turns. |
| `turnComplete` | boolean | Indicates if the user's turn is complete. |

### BidiGenerateContentRealtimeInput

Real-time streaming input for audio, video, and text. Can be sent continuously without interrupting model generation.

```json
{
  "audio": "base64-encoded-bytes",
  "video": "base64-encoded-bytes",
  "text": "string",
  "activityStart": {},
  "activityEnd": {},
  "audioStreamEnd": true
}
```

| Field | Type | Description |
|-------|------|-------------|
| `audio` | bytes | Raw audio data (base64 encoded). |
| `video` | bytes | Raw video data (base64 encoded). |
| `text` | string | Text input. |
| `activityStart` | object | Signals start of user activity. |
| `activityEnd` | object | Signals end of user activity. |
| `audioStreamEnd` | boolean | Indicates microphone disconnection. |

**Note**: Ordering across concurrent streams (audio, video, text) is not guaranteed.

### BidiGenerateContentToolResponse

Response to a function call request from the server.

```json
{
  "functionResponses": [
    {
      "id": "call_abc123",
      "name": "get_weather",
      "response": {
        "temperature": 72,
        "conditions": "sunny"
      }
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `functionResponses` | array | Array of function response objects. |
| `functionResponses[].id` | string | ID matching the original function call. |
| `functionResponses[].name` | string | Name of the function. |
| `functionResponses[].response` | object | The function's return value. |

## Server Messages

Server responses contain exactly one primary field plus optional `usageMetadata`.

### BidiGenerateContentSetupComplete

Confirms that session setup is complete. Contains no additional data.

```json
{
  "setupComplete": {}
}
```

### BidiGenerateContentServerContent

Model-generated response content.

```json
{
  "serverContent": {
    "modelTurn": {
      "parts": [
        {
          "text": "Hello! I'm doing well, thank you for asking."
        }
      ]
    },
    "turnComplete": true,
    "interrupted": false,
    "generationComplete": true,
    "groundingMetadata": {},
    "inputTranscription": {
      "text": "Hello, how are you?"
    },
    "outputTranscription": {
      "text": "Hello! I'm doing well, thank you for asking."
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `modelTurn` | Content | The model's response content. |
| `turnComplete` | boolean | Indicates if the model's turn is complete. |
| `interrupted` | boolean | Whether the response was interrupted by user. |
| `generationComplete` | boolean | Whether generation is fully complete (see note below). |
| `groundingMetadata` | object | Grounding information if search was used. |
| `inputTranscription` | object | Transcription of user's audio input. |
| `outputTranscription` | object | Transcription of model's audio output. |

#### Turn Complete vs Generation Complete

These two flags serve different purposes:

| Flag | Meaning | When to use |
|------|---------|-------------|
| `turnComplete` | The full turn (including pending operations) is complete. | Primary signal for turn boundaries. Use this to determine when to flush audio caches, update state, and prepare for next turn. |
| `generationComplete` | The model has finished generating content. | May arrive before `turnComplete`. On Google AI (Gemini API), used as a fallback signal to flush pending transcriptions. |

**Important**: The API may not always send a transcription `finished` signal. Use `generationComplete`, `turnComplete`, or `interrupted` as fallback signals to flush pending transcriptions.

### BidiGenerateContentToolCall

Request for the client to execute one or more functions.

```json
{
  "toolCall": {
    "functionCalls": [
      {
        "id": "call_abc123",
        "name": "get_weather",
        "args": {
          "location": "San Francisco"
        }
      }
    ]
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `functionCalls` | array | Array of function call requests. |
| `functionCalls[].id` | string | Unique identifier for this call. |
| `functionCalls[].name` | string | Name of the function to execute. |
| `functionCalls[].args` | object | Arguments to pass to the function. |

### BidiGenerateContentToolCallCancellation

Indicates that previous function calls were canceled due to user interruption.

```json
{
  "toolCallCancellation": {
    "ids": ["call_abc123", "call_def456"]
  }
}
```

### GoAway

Server notification that the connection will be closed.

```json
{
  "goAway": {
    "timeLeft": "30s"
  }
}
```

### SessionResumptionUpdate

Provides a handle for resuming the session later.

```json
{
  "sessionResumptionUpdate": {
    "handle": "session_handle_xyz"
  }
}
```

### UsageMetadata

Token usage information included with responses.

```json
{
  "usageMetadata": {
    "promptTokenCount": 150,
    "cachedContentTokenCount": 0,
    "responseTokenCount": 45,
    "toolUsePromptTokenCount": 0,
    "thoughtsTokenCount": 0,
    "totalTokenCount": 195,
    "promptTokensDetails": [
      {
        "modality": "AUDIO",
        "tokenCount": 100
      },
      {
        "modality": "TEXT",
        "tokenCount": 50
      }
    ],
    "responseTokensDetails": [
      {
        "modality": "AUDIO",
        "tokenCount": 45
      }
    ]
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `promptTokenCount` | integer | Tokens in the prompt. |
| `cachedContentTokenCount` | integer | Tokens from cached content. |
| `responseTokenCount` | integer | Tokens in the response. |
| `toolUsePromptTokenCount` | integer | Tokens used for tool calls. |
| `thoughtsTokenCount` | integer | Tokens used for thinking. |
| `totalTokenCount` | integer | Total tokens used. |
| `promptTokensDetails` | array | Per-modality token breakdown for input. |
| `responseTokensDetails` | array | Per-modality token breakdown for output. |

## Content Object

The Content object represents a turn in the conversation.

```json
{
  "role": "user",
  "parts": [
    {
      "text": "string"
    },
    {
      "inlineData": {
        "mimeType": "audio/pcm",
        "data": "base64-encoded-bytes"
      }
    },
    {
      "functionResponse": {
        "name": "function_name",
        "response": {}
      }
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `role` | string | Either `user` or `model`. |
| `parts` | array | Array of Part objects. |

## Part Object

Parts can contain text, inline data, or function responses.

| Part Type | Fields | Description |
|-----------|--------|-------------|
| Text | `text: string` | Plain text content. |
| Inline Data | `inlineData.mimeType`, `inlineData.data` | Binary data with MIME type. |
| Function Response | `functionResponse.name`, `functionResponse.response` | Response from a function call. |
