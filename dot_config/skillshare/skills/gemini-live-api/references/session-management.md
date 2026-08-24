# Session Management

The Gemini Live API maintains stateful sessions over WebSocket connections. Understanding session lifecycle and context management is essential for building robust applications.

## Session Lifecycle

```
┌─────────────────┐
│  Connect        │  WebSocket connection established
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Setup          │  Send BidiGenerateContentSetup
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  SetupComplete  │  Receive confirmation
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Active Session │  Exchange messages
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Disconnect     │  Close WebSocket or receive GoAway
└─────────────────┘
```

## Session Duration Limits

| Session Type | Maximum Duration |
|--------------|-----------------|
| Audio only | 15 minutes |
| Audio + Video | 2 minutes |

Sessions automatically terminate when limits are reached. Use session resumption to extend beyond these limits.

## Context Window

| Model Type | Context Window |
|------------|---------------|
| Native Audio Models | 128k tokens |
| Standard Models | 32k tokens |

The context includes all conversation history, audio transcriptions, and function call/response data.

## Session Setup

### Basic Setup

```json
{
  "setup": {
    "model": "gemini-2.5-flash-native-audio-preview-12-2025",
    "generationConfig": {
      "responseModalities": ["AUDIO"]
    }
  }
}
```

### Setup Complete Response

```json
{
  "setupComplete": {}
}
```

Wait for `setupComplete` before sending other messages.

## Session Resumption

Enable long-running conversations by resuming sessions:

### Enable Resumption in Setup

```json
{
  "setup": {
    "model": "gemini-2.5-flash-native-audio-preview-12-2025",
    "sessionResumption": {}
  }
}
```

### Receive Resumption Handle

The server periodically sends resumption updates:

```json
{
  "sessionResumptionUpdate": {
    "handle": "session_handle_abc123xyz"
  }
}
```

Store the latest handle for later use.

### Resume a Session

Start a new connection with the previous handle:

```json
{
  "setup": {
    "model": "gemini-2.5-flash-native-audio-preview-12-2025",
    "sessionResumption": {
      "handle": "session_handle_abc123xyz"
    }
  }
}
```

### Resumption Limitations

Session resumption is not available when:

- Active function execution is in progress.
- Model is generating a response.
- Session has expired.

## Context Window Compression

Manage context size automatically with sliding window compression:

```json
{
  "setup": {
    "contextWindowCompression": {
      "slidingWindow": {
        "targetTokens": 16000
      },
      "triggerTokens": 24000
    }
  }
}
```

| Field | Description |
|-------|-------------|
| `targetTokens` | Token count after compression. |
| `triggerTokens` | Token count that triggers compression. Default: 80% of context limit. |

When `triggerTokens` is exceeded, older context is summarized to reach `targetTokens`.

## GoAway Messages

The server sends `GoAway` before terminating a connection:

```json
{
  "goAway": {
    "timeLeft": "30s"
  }
}
```

When you receive `GoAway`:

1. Complete any pending operations.
2. Store the latest resumption handle.
3. Prepare to reconnect if needed.

## Python Session Example

```python
from google import genai
from google.genai.types import LiveConnectConfig, Modality

client = genai.Client(api_key="YOUR_API_KEY")

class SessionManager:
    def __init__(self):
        self.resumption_handle = None

    async def start_session(self):
        config = LiveConnectConfig(
            response_modalities=[Modality.AUDIO],
            session_resumption={},
        )

        # Resume if we have a handle.
        if self.resumption_handle:
            config.session_resumption = {
                "handle": self.resumption_handle
            }

        async with client.aio.live.connect(
            model="gemini-2.5-flash-native-audio-preview-12-2025",
            config=config,
        ) as session:
            await self.handle_session(session)

    async def handle_session(self, session):
        async for message in session.receive():
            # Store resumption handle.
            if message.session_resumption_update:
                self.resumption_handle = message.session_resumption_update.handle

            # Handle GoAway.
            if message.go_away:
                print(f"Session ending in {message.go_away.time_left}")
                # Reconnect with stored handle.
                await self.start_session()
                return

            # Process other messages.
            if message.server_content:
                yield message.server_content
```

## JavaScript Session Example

```javascript
const { GoogleGenAI } = require('@google/genai');

const client = new GoogleGenAI({ apiKey: process.env.GOOGLE_API_KEY });

class SessionManager {
  constructor() {
    this.resumptionHandle = null;
    this.session = null;
  }

  async connect() {
    const config = {
      responseModalities: ['AUDIO'],
      sessionResumption: this.resumptionHandle
        ? { handle: this.resumptionHandle }
        : {},
    };

    this.session = await client.live.connect({
      model: 'gemini-2.5-flash-native-audio-preview-12-2025',
      config,
      callbacks: {
        onmessage: (msg) => this.handleMessage(msg),
        onerror: (e) => this.handleError(e),
        onclose: () => this.handleClose(),
      },
    });
  }

  handleMessage(msg) {
    if (msg.sessionResumptionUpdate) {
      this.resumptionHandle = msg.sessionResumptionUpdate.handle;
    }

    if (msg.goAway) {
      console.log(`Session ending in ${msg.goAway.timeLeft}`);
      this.reconnect();
    }
  }

  async reconnect() {
    if (this.session) {
      this.session.close();
    }
    await this.connect();
  }
}
```

## Sending History to a New Connection

When establishing a new Live connection (e.g., after agent transfer or resuming with previous ADK session history), you should filter audio parts from the history before sending.

### Why Filter Audio Parts

Audio parts should be excluded when sending conversation history because:

1. **Audio has already been transcribed**: The transcription is in the context; sending raw audio is redundant.
2. **Sending audio via `send_client_content` is not supported**: The Live API expects audio only via `send_realtime_input`. Sending audio through the content stream corrupts the session.

### Implementation Pattern

```python
def filter_audio_parts(content: Content) -> Content | None:
    """Filter out audio parts from content before sending to Live API."""
    if not content or not content.parts:
        return None

    filtered_parts = [
        part for part in content.parts
        if not (part.inline_data and part.inline_data.mime_type.startswith("audio/"))
    ]

    if not filtered_parts:
        return None

    return Content(role=content.role, parts=filtered_parts)

# When sending history to a new connection
async def send_history(session, history: list[Content]):
    contents = [
        filtered
        for content in history
        if (filtered := filter_audio_parts(content)) is not None
    ]

    if contents:
        await session.send_client_content(
            turns=contents,
            turn_complete=contents[-1].role == "user",
        )
```

## Conversation Context

The session maintains conversation history automatically. You can also explicitly add context:

### Add Conversation History

```json
{
  "clientContent": {
    "turns": [
      {
        "role": "user",
        "parts": [{ "text": "My name is Alice." }]
      },
      {
        "role": "model",
        "parts": [{ "text": "Nice to meet you, Alice!" }]
      }
    ],
    "turnComplete": true
  }
}
```

### Interruption and Context

When a user interrupts:

1. Ongoing generation is canceled.
2. Only content already sent to the client is retained.
3. Canceled content is not added to history.

## Token Usage Tracking

Monitor token consumption via `usageMetadata`:

```json
{
  "usageMetadata": {
    "promptTokenCount": 1500,
    "responseTokenCount": 250,
    "totalTokenCount": 1750
  }
}
```

Track usage to anticipate when context compression will trigger.

## Multi-Session Architecture

For applications with multiple concurrent users:

```
                    ┌─────────────┐
                    │   Client 1  │
                    └──────┬──────┘
                           │
┌─────────────────┐        ▼        ┌─────────────────────┐
│   Client 2      │───►┌───────┐───►│  Gemini Live API    │
└─────────────────┘    │ Server │   │  (per-client        │
                       └───────┘   │   WebSocket)         │
┌─────────────────┐        ▲        └─────────────────────┘
│   Client N      │────────┘
└─────────────────┘
```

Each client maintains its own session with:

- Separate context and history.
- Independent resumption handles.
- Individual token tracking.

## Error Handling

### Connection Errors

```python
async def robust_session():
    max_retries = 3
    retry_delay = 1

    for attempt in range(max_retries):
        try:
            async with client.aio.live.connect(...) as session:
                await handle_session(session)
                break
        except ConnectionError as e:
            if attempt < max_retries - 1:
                await asyncio.sleep(retry_delay * (attempt + 1))
            else:
                raise
```

### Session Expiration

When a resumption handle expires:

1. Create a new session without the handle.
2. Optionally replay important context.
3. Inform the user of context loss.

## Best Practices

1. **Store resumption handles persistently**: Save handles to survive application restarts.

2. **Monitor token usage**: Track `usageMetadata` to predict compression events.

3. **Handle GoAway gracefully**: Always prepare for session termination.

4. **Implement reconnection logic**: Sessions can disconnect unexpectedly.

5. **Use context compression**: Configure compression to avoid hitting limits.

6. **Separate concerns**: Keep session management logic separate from business logic.

7. **Log session events**: Track setup, resumption, and disconnection for debugging.
