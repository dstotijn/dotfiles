---
name: gemini-live-api
description: Use when implementing real-time voice/video with Gemini models, bidirectional streaming, WebSocket audio, voice activity detection, or live function calling with Google Gen AI SDK.
---

# Gemini Live API

## Overview

The Gemini Live API enables low-latency, real-time bidirectional voice and video interactions with Gemini models via WebSockets. Based on the [google/adk-python](https://github.com/google/adk-python) reference implementation.

## Key Capabilities

| Feature | Description |
|---------|-------------|
| Multimodal I/O | Text, audio, and video input; text and audio output |
| Voice Activity Detection | Automatic speech detection with barge-in |
| Function Calling | Tool integration for external services |
| Session Memory | Context retention within sessions |
| Multilingual | 24 languages with automatic switching |

## Supported Models

| Model ID | Status |
|----------|--------|
| `gemini-2.5-flash-native-audio-preview-12-2025` | Preview |
| `gemini-live-2.5-flash-native-audio` | GA |

## Audio Specifications

| Direction | Format |
|-----------|--------|
| Input | 16-bit PCM, 16kHz, mono, little-endian |
| Output | 16-bit PCM, 24kHz, little-endian |

## Quick Start (Python)

```python
from google import genai
from google.genai.types import LiveConnectConfig, Modality

client = genai.Client(api_key="YOUR_API_KEY")

async with client.aio.live.connect(
    model="gemini-2.5-flash-native-audio-preview-12-2025",
    config=LiveConnectConfig(response_modalities=[Modality.AUDIO]),
) as session:
    # Send text content (turn_complete=True triggers model response).
    await session.send_client_content(
        turns=[{"role": "user", "parts": [{"text": "Hello!"}]}],
        turn_complete=True,
    )

    # Or send realtime audio.
    await session.send_realtime_input(media=audio_blob)

    # Receive responses.
    async for message in session.receive():
        if message.server_content and message.server_content.turn_complete:
            break
```

## Core Connection Pattern (from adk-python)

The `GeminiLlmConnection` class wraps `live.AsyncSession` with these key methods:

| Method | Purpose |
|--------|---------|
| `send_history()` | Send conversation history (filters audio parts) |
| `send_content()` | Send user content or function responses |
| `send_realtime()` | Send audio blobs or activity signals |
| `receive()` | Async generator yielding `LlmResponse` objects |
| `close()` | Terminate the session |

### Realtime Input Types

```python
from google.genai import types

RealtimeInput = Union[types.Blob, types.ActivityStart, types.ActivityEnd]
```

## Reference Files

Detailed documentation in `references/`:

| File | Content |
|------|---------|
| [README.md](references/README.md) | Overview, architecture, quick start |
| [python-sdk.md](references/python-sdk.md) | Google Gen AI Python SDK |
| [message-types.md](references/message-types.md) | Client and server message schemas |
| [configuration.md](references/configuration.md) | Session, VAD, and speech config |
| [audio-video.md](references/audio-video.md) | Media handling and specifications |
| [voice-configuration.md](references/voice-configuration.md) | Available voices and languages |
| [function-calling.md](references/function-calling.md) | Tool use and function integration |
| [session-management.md](references/session-management.md) | Context and session handling |
| [event-flows.md](references/event-flows.md) | Turn completion, transcription, interruptions |
| [code-examples.md](references/code-examples.md) | Implementation examples |

## Key Implementation Insights

### Triggering Model Response After Connection

To have the model start talking after setup, send initial content where the **last turn is from the user** with `turn_complete: true`:

```python
# Model responds immediately when last turn is from user + turn_complete=True.
await session.send_client_content(
    turns=[{"role": "user", "parts": [{"text": "Hello!"}]}],
    turn_complete=True,
)
```

The `turn_complete` flag controls inference:

| Last message role | turn_complete | Model behavior |
|-------------------|---------------|----------------|
| `user` | `True` | Model responds immediately |
| `model` | `False` | Model waits for user input |

For a greeting without explicit user input, use a system instruction:

```python
config = LiveConnectConfig(
    response_modalities=[Modality.AUDIO],
    system_instruction="When the conversation starts, introduce yourself.",
)

# Minimal trigger to start the model.
await session.send_client_content(
    turns=[{"role": "user", "parts": [{"text": "."}]}],
    turn_complete=True,
)
```

### Audio Parts Must Be Filtered from History

When sending conversation history to a new connection, filter out audio parts:

```python
# Audio has already been transcribed and sending via send_client_content
# corrupts the session. Only send audio via send_realtime_input.
contents = [
    filtered
    for content in history
    if (filtered := filter_audio_parts(content)) is not None
]
```

### Transcription Handling

Transcriptions accumulate and are emitted with `finished=True` on completion:

```python
# Partial transcriptions accumulate.
self._input_transcription_text += message.server_content.input_transcription.text

# On finished signal, emit complete transcription.
if message.server_content.input_transcription.finished:
    yield LlmResponse(
        input_transcription=types.Transcription(
            text=self._input_transcription_text,
            finished=True,
        ),
    )
    self._input_transcription_text = ''
```

### Turn Completion Signals

The API may not always send a transcription `finished` signal. Use these as fallbacks:

- `turn_complete` - Primary signal for turn boundaries
- `generation_complete` - Model finished generating
- `interrupted` - User interrupted the model

### Function Calling

Function responses must be sent as `LiveClientToolResponse`:

```python
if content.parts[0].function_response:
    function_responses = [part.function_response for part in content.parts]
    await session.send(
        input=types.LiveClientToolResponse(function_responses=function_responses)
    )
```

## Session Limits

| Limit | Value |
|-------|-------|
| Session duration (audio only) | 15 minutes |
| Session duration (audio+video) | 2 minutes |
| Context window (native audio) | 128k tokens |

## Debugging

1. **Authentication**: Ensure API key is set or use `GOOGLE_API_KEY` env var
2. **Audio format**: Input must be 16-bit PCM, 16kHz, mono
3. **Session corruption**: Never send audio via `send_client_content`; use `send_realtime_input`

## External References

- [Google Gen AI Python SDK](https://github.com/googleapis/python-genai)
- [ADK Python Reference](https://github.com/google/adk-python)
- [Gemini API Live Docs](https://ai.google.dev/gemini-api/docs/multimodal-live)
