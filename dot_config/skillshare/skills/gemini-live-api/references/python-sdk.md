# Google Gen AI Python SDK

The Google Gen AI Python SDK (`google-genai`) provides a unified interface for integrating Gemini models into Python applications, including the Live API for real-time bidirectional communication.

## Installation

```bash
pip install google-genai
```

## Client Configuration

### API Key Setup

```python
from google import genai

client = genai.Client(api_key="YOUR_API_KEY")
```

### Environment Variable Configuration

```bash
export GOOGLE_API_KEY='your-api-key'
```

```python
# With environment variable set, use default config.
client = genai.Client()
```

## Live API

The Live API enables real-time bidirectional communication with Gemini models via WebSockets.

### Core Types

```python
from google.genai import live, types

# Entry point for Live connections.
client.aio.live  # AsyncLive instance

# Active WebSocket session.
session: live.AsyncSession

# Configuration for Live connection.
config: types.LiveConnectConfig
```

### Session Methods

| Method | Description |
|--------|-------------|
| `send_client_content(turns, turn_complete)` | Send turn-based content (text, tool responses) |
| `send_realtime_input(media, activity_start, activity_end)` | Send real-time audio/video data |
| `send_tool_response(function_responses)` | Respond to function calls |
| `receive()` | Async generator yielding server messages |
| `close()` | Terminate the connection |

### Basic Example

```python
import asyncio
from google import genai
from google.genai.types import Content, LiveConnectConfig, Modality, Part

client = genai.Client(api_key="YOUR_API_KEY")

async def main():
    model = "gemini-2.5-flash-native-audio-preview-12-2025"

    async with client.aio.live.connect(
        model=model,
        config=LiveConnectConfig(
            system_instruction="You are a helpful assistant.",
            response_modalities=[Modality.TEXT],
        ),
    ) as session:
        # Send text message.
        await session.send_client_content(
            turns=Content(role="user", parts=[Part(text="Hello!")])
        )

        # Receive responses.
        async for message in session.receive():
            if message.text:
                print(message.text)
            if message.server_content and message.server_content.turn_complete:
                break

asyncio.run(main())
```

### Audio Streaming Example

```python
import asyncio
import base64
from google import genai
from google.genai.types import (
    Blob,
    LiveConnectConfig,
    Modality,
    PrebuiltVoiceConfig,
    SpeechConfig,
    VoiceConfig,
)

client = genai.Client(api_key="YOUR_API_KEY")

async def audio_conversation():
    model = "gemini-2.5-flash-native-audio-preview-12-2025"

    config = LiveConnectConfig(
        response_modalities=[Modality.AUDIO],
        speech_config=SpeechConfig(
            voice_config=VoiceConfig(
                prebuilt_voice_config=PrebuiltVoiceConfig(voice_name="Puck")
            ),
            language_code="en-US",
        ),
    )

    async with client.aio.live.connect(model=model, config=config) as session:
        # Send audio (16-bit PCM, 16kHz, mono).
        audio_data = get_audio_chunk()  # Your audio source
        await session.send_realtime_input(
            media=Blob(mime_type="audio/pcm;rate=16000", data=audio_data)
        )

        # Receive audio responses (24kHz).
        async for message in session.receive():
            if message.server_content and message.server_content.model_turn:
                for part in message.server_content.model_turn.parts:
                    if part.inline_data:
                        play_audio(part.inline_data.data)

            if message.server_content and message.server_content.turn_complete:
                break

asyncio.run(audio_conversation())
```

### Function Calling Example

```python
import asyncio
from google import genai
from google.genai.types import (
    FunctionDeclaration,
    LiveConnectConfig,
    Modality,
    Tool,
)

client = genai.Client(api_key="YOUR_API_KEY")

# Define tools.
tools = [
    Tool(
        function_declarations=[
            FunctionDeclaration(
                name="get_weather",
                description="Get current weather for a location",
                parameters={
                    "type": "object",
                    "properties": {
                        "location": {
                            "type": "string",
                            "description": "City name",
                        },
                    },
                    "required": ["location"],
                },
            ),
        ]
    )
]

async def function_calling_example():
    model = "gemini-2.5-flash-native-audio-preview-12-2025"

    config = LiveConnectConfig(
        response_modalities=[Modality.TEXT],
        tools=tools,
    )

    async with client.aio.live.connect(model=model, config=config) as session:
        await session.send_client_content(
            turns=[{
                "role": "user",
                "parts": [{"text": "What's the weather in Paris?"}]
            }]
        )

        async for message in session.receive():
            # Handle function call.
            if message.tool_call:
                for call in message.tool_call.function_calls:
                    result = handle_function(call.name, call.args)

                    await session.send_tool_response(
                        function_responses=[{
                            "id": call.id,
                            "name": call.name,
                            "response": result,
                        }]
                    )

            # Handle text response.
            if message.text:
                print(message.text)

            # Handle turn completion.
            if message.server_content and message.server_content.turn_complete:
                break

def handle_function(name: str, args: dict) -> dict:
    if name == "get_weather":
        return {"temperature": 22, "conditions": "sunny"}
    return {"error": f"Unknown function: {name}"}

asyncio.run(function_calling_example())
```

## Message Types

### Server Messages

| Field | Type | Description |
|-------|------|-------------|
| `server_content` | `LiveServerContent` | Model responses with `model_turn` and `turn_complete` |
| `tool_call` | `LiveServerToolCall` | Function execution request |
| `tool_call_cancellation` | `LiveServerToolCallCancellation` | Cancel pending function call |
| `session_resumption_update` | `LiveServerSessionResumptionUpdate` | Session checkpoint |
| `usage_metadata` | `UsageMetadata` | Token usage information |

### LiveServerContent Fields

```python
if message.server_content:
    # Model's response content.
    model_turn = message.server_content.model_turn

    # Turn completion signals.
    turn_complete = message.server_content.turn_complete
    generation_complete = message.server_content.generation_complete
    interrupted = message.server_content.interrupted

    # Transcriptions.
    input_transcription = message.server_content.input_transcription
    output_transcription = message.server_content.output_transcription
```

## Configuration Options

### LiveConnectConfig

```python
from google.genai.types import (
    LiveConnectConfig,
    Modality,
    SpeechConfig,
    VoiceConfig,
    PrebuiltVoiceConfig,
    RealtimeInputConfig,
    AutomaticActivityDetection,
)

config = LiveConnectConfig(
    # Response format.
    response_modalities=[Modality.AUDIO],  # or [Modality.TEXT]

    # System instruction.
    system_instruction="You are a helpful assistant.",

    # Voice configuration.
    speech_config=SpeechConfig(
        voice_config=VoiceConfig(
            prebuilt_voice_config=PrebuiltVoiceConfig(voice_name="Puck")
        ),
        language_code="en-US",
    ),

    # Voice activity detection.
    realtime_input_config=RealtimeInputConfig(
        automatic_activity_detection=AutomaticActivityDetection(
            disabled=False,
            silence_duration_ms=1000,
        ),
    ),

    # Tools.
    tools=[Tool(function_declarations=[...])],
)
```

## GeminiLlmConnection Pattern (from adk-python)

The [adk-python](https://github.com/google/adk-python) reference implementation shows how to build a robust connection wrapper:

```python
from google.genai import types
from typing import AsyncGenerator, Union

RealtimeInput = Union[types.Blob, types.ActivityStart, types.ActivityEnd]

class GeminiLlmConnection:
    def __init__(self, session: live.AsyncSession):
        self._session = session
        self._input_transcription_text = ''
        self._output_transcription_text = ''

    async def send_history(self, history: list[types.Content]):
        """Send conversation history, filtering audio parts."""
        # Filter audio - it's already transcribed and sending it corrupts the session.
        contents = [
            filtered
            for content in history
            if (filtered := filter_audio_parts(content)) is not None
        ]

        if contents:
            await self._session.send(
                input=types.LiveClientContent(
                    turns=contents,
                    turn_complete=contents[-1].role == 'user',
                )
            )

    async def send_content(self, content: types.Content):
        """Send user content or function responses."""
        if content.parts[0].function_response:
            # All parts must be function responses.
            function_responses = [part.function_response for part in content.parts]
            await self._session.send(
                input=types.LiveClientToolResponse(function_responses=function_responses)
            )
        else:
            await self._session.send(
                input=types.LiveClientContent(turns=[content], turn_complete=True)
            )

    async def send_realtime(self, input: RealtimeInput):
        """Send audio blobs or activity signals."""
        if isinstance(input, types.Blob):
            await self._session.send_realtime_input(media=input)
        elif isinstance(input, types.ActivityStart):
            await self._session.send_realtime_input(activity_start=input)
        elif isinstance(input, types.ActivityEnd):
            await self._session.send_realtime_input(activity_end=input)

    async def receive(self) -> AsyncGenerator[LlmResponse, None]:
        """Receive and process model responses."""
        async for message in self._session.receive():
            # Process transcriptions, accumulating partial text.
            if message.server_content:
                if message.server_content.input_transcription:
                    if message.server_content.input_transcription.text:
                        self._input_transcription_text += (
                            message.server_content.input_transcription.text
                        )
                    if message.server_content.input_transcription.finished:
                        yield LlmResponse(
                            input_transcription=types.Transcription(
                                text=self._input_transcription_text,
                                finished=True,
                            )
                        )
                        self._input_transcription_text = ''

                # Use turn_complete as primary signal for turn boundaries.
                if message.server_content.turn_complete:
                    yield LlmResponse(turn_complete=True)
                    break

            # Handle tool calls.
            if message.tool_call:
                parts = [
                    types.Part(function_call=fc)
                    for fc in message.tool_call.function_calls
                ]
                yield LlmResponse(content=types.Content(role='model', parts=parts))

    async def close(self):
        await self._session.close()
```

## Audio Specifications

| Direction | Format |
|-----------|--------|
| Input | 16-bit PCM, 16kHz, mono, little-endian |
| Output | 16-bit PCM, 24kHz, little-endian |

MIME type for input: `audio/pcm;rate=16000`

## Error Handling

```python
async with client.aio.live.connect(model=model, config=config) as session:
    try:
        async for message in session.receive():
            # Handle messages.
            pass
    except ConnectionError as e:
        print(f"Connection error: {e}")
    except Exception as e:
        print(f"Error: {e}")
```

## References

- [Python SDK GitHub Repository](https://github.com/googleapis/python-genai)
- [ADK Python Reference](https://github.com/google/adk-python)
- [Gemini API Documentation](https://ai.google.dev/gemini-api/docs)
