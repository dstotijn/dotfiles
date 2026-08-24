# Gemini Live API

The Gemini Live API enables low-latency, real-time bidirectional voice and video interactions with Gemini. It processes continuous streams of audio, video, or text to deliver immediate, human-like spoken responses.

## Key Features

- **Multimodal Input/Output**: Text, audio, and video processing with text and audio output.
- **Low-Latency Responses**: Real-time interaction support for natural conversations.
- **Voice Activity Detection (VAD)**: Automatic detection of speech with barge-in capability.
- **Session Memory**: Retains context within a single session.
- **Affective Dialog**: Adapts response style and tone to match user expression.
- **Function Calling**: Integration with tools and external services.
- **Multilingual Support**: 24 languages with automatic switching.

## Supported Models

| Model ID | Description | Status |
|----------|-------------|--------|
| `gemini-live-2.5-flash-native-audio` | Native audio model with HD voices | GA |
| `gemini-2.5-flash-native-audio-preview-12-2025` | Preview version | Preview |

## Architecture

The API uses a stateful WebSocket connection for bidirectional communication:

```
┌─────────┐     WebSocket      ┌─────────────────┐
│  Client │ ◄──────────────────► │  Gemini Live API │
└─────────┘                     └─────────────────┘
     │                                   │
     │  Audio/Video/Text ───────────►    │
     │  ◄─────────── Audio/Text Response │
```

### Implementation Approaches

1. **Server-to-Server** (Recommended for production): Backend connects via WebSockets; client streams to your server, which forwards to the API.

2. **Client-to-Server**: Frontend connects directly to Live API via WebSockets. Better performance but requires ephemeral tokens for production security.

## Quick Start (Python)

```python
from google import genai
from google.genai.types import Content, LiveConnectConfig, Modality, Part

client = genai.Client(api_key="YOUR_API_KEY")
model_id = "gemini-2.5-flash-native-audio-preview-12-2025"

async with client.aio.live.connect(
    model=model_id,
    config=LiveConnectConfig(response_modalities=[Modality.TEXT]),
) as session:
    text_input = "Hello? Gemini, are you there?"
    await session.send_client_content(
        turns=Content(role="user", parts=[Part(text=text_input)])
    )

    response = []
    async for message in session.receive():
        if message.text:
            response.append(message.text)
    print("".join(response))
```

## Session Methods

The `live.AsyncSession` class provides these key methods:

| Method | Description |
|--------|-------------|
| `send_client_content()` | Send turn-based content (text, tool responses). Messages are added to context in order. |
| `send_realtime_input()` | Send real-time audio/video data. Model responds based on VAD. |
| `send_tool_response()` | Respond to function calls from the server. |
| `receive()` | Async generator yielding model responses. |
| `close()` | Terminate the connection. |

### send_client_content vs send_realtime_input

| Aspect | `send_client_content` | `send_realtime_input` |
|--------|----------------------|----------------------|
| Ordering | Messages added in order | Non-deterministic ordering |
| Response | Model responds immediately | Model uses VAD to decide when |
| Use case | Text, prefilling context | Live audio/video streaming |

## Technical Specifications

| Specification | Value |
|---------------|-------|
| Input Audio | 16-bit PCM, 16kHz, mono |
| Output Audio | 16-bit PCM, 24kHz |
| Video Frame Rate | 1 FPS |
| Context Window (Native Audio) | 128k tokens |
| Context Window (Standard) | 32k tokens |
| Audio Session Limit | 15 minutes |
| Audio+Video Session Limit | 2 minutes |

## Documentation Structure

- [Message Types](./message-types.md) - Client and server message schemas.
- [Configuration](./configuration.md) - Session and generation configuration.
- [Audio & Video](./audio-video.md) - Media handling and specifications.
- [Voice Configuration](./voice-configuration.md) - Available voices and languages.
- [Function Calling](./function-calling.md) - Tool use and function integration.
- [Session Management](./session-management.md) - Context and session handling.
- [Event Flows](./event-flows.md) - Turn completion, transcription streaming, interruption handling.
- [Code Examples](./code-examples.md) - Implementation examples.
- [Python SDK](./python-sdk.md) - Google Gen AI Python SDK reference.

## Key Implementation Insights

These insights come from the [adk-python](https://github.com/google/adk-python) reference implementation:

### Audio Parts Must Be Filtered from History

When sending conversation history to a new connection (e.g., after agent transfer), filter out audio parts:

```python
# Audio has already been transcribed.
# Sending audio via send_client_content corrupts the session.
contents = [
    filtered
    for content in history
    if (filtered := filter_audio_parts(content)) is not None
]
```

### Turn Completion

Turn completion signals include:
- `turn_complete` - Primary signal for turn boundaries
- `generation_complete` - Model finished generating content
- `interrupted` - User interrupted the model

The API may not always send a transcription `finished` signal. Use `turn_complete`, `generation_complete`, or `interrupted` as fallback signals to flush pending transcriptions.

### Transcription Aggregation

User transcriptions arrive as single words or short phrases, not complete sentences. You must aggregate them yourself using end-of-sentence detection with a timeout fallback (typically 500ms).

### User Speech Boundaries

The API does not provide reliable `UserStartedSpeaking`/`UserStoppedSpeaking` signals. Use independent VAD (like Silero) for turn tracking in your application.

### Graceful Shutdown

Defer `EndFrame` handling until after `turn_complete` arrives to ensure the model finishes its response before disconnecting.

## References

- [Google Gen AI Python SDK](https://github.com/googleapis/python-genai)
- [ADK Python Reference](https://github.com/google/adk-python)
- [Gemini API Documentation](https://ai.google.dev/gemini-api/docs)
