# Audio & Video Handling

The Gemini Live API processes continuous streams of audio and video for real-time multimodal interactions.

## Audio Specifications

### Input Audio

| Specification | Value |
|---------------|-------|
| Format | 16-bit PCM |
| Sample Rate | 16 kHz (native), any rate accepted |
| Channels | Mono |
| Encoding | Linear PCM, signed |
| Chunk Size | 1024 bytes recommended |
| MIME Type | `audio/pcm;rate=16000` |

### Output Audio

| Specification | Value |
|---------------|-------|
| Format | 16-bit PCM |
| Sample Rate | 24 kHz |
| Channels | Mono |
| Encoding | Base64-encoded PCM |

## Video Specifications

| Specification | Value |
|---------------|-------|
| Frame Rate | 1 FPS (processed) |
| Format | JPEG |
| Resolution | Configurable via `mediaResolution` |

## Sending Audio

Audio is sent via `BidiGenerateContentRealtimeInput` messages:

```json
{
  "realtimeInput": {
    "audio": "base64-encoded-pcm-data"
  }
}
```

### Python Example

```python
import pyaudio
import base64
import asyncio

CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000

p = pyaudio.PyAudio()
stream = p.open(
    format=FORMAT,
    channels=CHANNELS,
    rate=RATE,
    input=True,
    frames_per_buffer=CHUNK
)

async def send_audio(session):
    while True:
        data = stream.read(CHUNK, exception_on_overflow=False)
        encoded = base64.b64encode(data).decode('utf-8')
        await session.send_realtime_input(audio=encoded)
        await asyncio.sleep(0.01)
```

### JavaScript Example

```javascript
const mic = require('mic');

const micInstance = mic({
  rate: '16000',
  channels: '1',
  bitwidth: '16',
  encoding: 'signed-integer',
});

const micInputStream = micInstance.getAudioStream();

micInputStream.on('data', (data) => {
  const base64Audio = data.toString('base64');
  session.sendRealtimeInput({ audio: base64Audio });
});

micInstance.start();
```

## Receiving Audio

Audio output is received in `BidiGenerateContentServerContent` messages:

```json
{
  "serverContent": {
    "modelTurn": {
      "parts": [
        {
          "inlineData": {
            "mimeType": "audio/pcm;rate=24000",
            "data": "base64-encoded-audio"
          }
        }
      ]
    }
  }
}
```

### Python Playback Example

```python
import pyaudio
import base64

OUTPUT_RATE = 24000
p = pyaudio.PyAudio()
output_stream = p.open(
    format=pyaudio.paInt16,
    channels=1,
    rate=OUTPUT_RATE,
    output=True
)

async def receive_audio(session):
    async for message in session.receive():
        if message.server_content and message.server_content.model_turn:
            for part in message.server_content.model_turn.parts:
                if part.inline_data:
                    audio_data = base64.b64decode(part.inline_data.data)
                    output_stream.write(audio_data)
```

### JavaScript Playback Example

```javascript
const Speaker = require('speaker');

const speaker = new Speaker({
  channels: 1,
  bitDepth: 16,
  sampleRate: 24000,
});

session.on('message', (msg) => {
  if (msg.serverContent?.modelTurn?.parts) {
    for (const part of msg.serverContent.modelTurn.parts) {
      if (part.inlineData) {
        const audioBuffer = Buffer.from(part.inlineData.data, 'base64');
        speaker.write(audioBuffer);
      }
    }
  }
});
```

## Sending Video

Video frames are sent via `BidiGenerateContentRealtimeInput`:

```json
{
  "realtimeInput": {
    "video": "base64-encoded-jpeg-data"
  }
}
```

### Python Video Capture Example

```python
import cv2
import base64
import asyncio

cap = cv2.VideoCapture(0)

async def send_video(session):
    while True:
        ret, frame = cap.read()
        if ret:
            _, buffer = cv2.imencode('.jpg', frame)
            encoded = base64.b64encode(buffer).decode('utf-8')
            await session.send_realtime_input(video=encoded)
        await asyncio.sleep(1.0)  # 1 FPS
```

## Audio Stream End

Signal microphone disconnection:

```json
{
  "realtimeInput": {
    "audioStreamEnd": true
  }
}
```

This tells the model that the audio input stream has ended.

## Activity Signals

For manual voice activity control (when automatic VAD is disabled or for precise turn control):

### Activity Start

```json
{
  "realtimeInput": {
    "activityStart": {}
  }
}
```

### Activity End

```json
{
  "realtimeInput": {
    "activityEnd": {}
  }
}
```

### Priority Order

When multiple fields are set in a realtime input message, they are processed by priority (highest first):

```
activity_start > activity_end > blob > content
```

This means activity signals are always processed before audio data, ensuring turn boundaries are respected.

### Python SDK Pattern (adk-python)

```python
from google.adk.agents import LiveRequestQueue

# Create request queue
live_request_queue = LiveRequestQueue()

# Signal user started speaking
live_request_queue.send_activity_start()

# Send audio chunks
live_request_queue.send_realtime(audio_blob)

# Signal user stopped speaking
live_request_queue.send_activity_end()
```

### When to Use Manual Activity Signals

| Use Case | Recommendation |
|----------|----------------|
| Natural conversation | Use automatic VAD (default) |
| Push-to-talk interface | Use manual signals with VAD disabled |
| Custom VAD integration | Use manual signals to relay your VAD's decisions |
| Precise turn control | Use manual signals for exact boundary control |
| Noisy environments | Consider manual signals with your own noise filtering |

## Voice Activity Detection (VAD)

VAD automatically recognizes when a person is speaking, enabling natural conversation flow and interruptions.

### How VAD Works

1. Continuously monitors audio input.
2. Detects speech onset and offset.
3. When interruption detected, cancels ongoing generation.
4. Only information already sent to client is retained.

### VAD Configuration

```json
{
  "realtimeInputConfig": {
    "automaticActivityDetection": {
      "disabled": false,
      "startOfSpeechSensitivity": "START_SENSITIVITY_HIGH",
      "prefixPaddingMs": 300,
      "endOfSpeechSensitivity": "END_SENSITIVITY_HIGH",
      "silenceDurationMs": 1000
    }
  }
}
```

| Parameter | Description |
|-----------|-------------|
| `startOfSpeechSensitivity` | How quickly to detect speech start. |
| `prefixPaddingMs` | Audio to include before detected speech. |
| `endOfSpeechSensitivity` | How quickly to detect speech end. |
| `silenceDurationMs` | Silence duration to trigger end of speech (default ~1 second). |

### Disabling VAD

For manual control over turn-taking:

```json
{
  "realtimeInputConfig": {
    "automaticActivityDetection": {
      "disabled": true
    }
  }
}
```

When disabled, use `activityStart` and `activityEnd` signals.

## Interruption Handling

Configure how the model handles user interruptions:

### Allow Interruptions (Default)

```json
{
  "realtimeInputConfig": {
    "activityHandling": "START_OF_ACTIVITY_INTERRUPTS"
  }
}
```

User speech cancels ongoing model generation.

### No Interruption

```json
{
  "realtimeInputConfig": {
    "activityHandling": "NO_INTERRUPTION"
  }
}
```

Model continues speaking despite user input.

## Transcription

### Enable Input Transcription

```json
{
  "inputAudioTranscription": {
    "model": "gemini-2.0-flash"
  }
}
```

Transcription returned in:

```json
{
  "serverContent": {
    "inputTranscription": {
      "text": "What's the weather like today?"
    }
  }
}
```

### Enable Output Transcription

```json
{
  "outputAudioTranscription": {}
}
```

Transcription returned in:

```json
{
  "serverContent": {
    "outputTranscription": {
      "text": "The weather today is sunny with a high of 72 degrees."
    }
  }
}
```

## Best Practices

1. **Use headphones**: Prevents echo and feedback loops during testing.

2. **Buffer audio**: Collect audio in chunks before sending to avoid excessive messages.

3. **Handle backpressure**: If sending faster than processing, implement buffering.

4. **Monitor latency**: Track round-trip time to optimize user experience.

5. **Graceful degradation**: Handle network issues by buffering or reducing quality.

6. **Echo cancellation**: Implement client-side echo cancellation for speaker output.

## Session Limits

| Session Type | Duration Limit |
|--------------|---------------|
| Audio only | 15 minutes |
| Audio + Video | 2 minutes |

Sessions can be extended using session management techniques like resumption handles.

## Concurrent Streams

Audio, video, and text can be sent concurrently via `BidiGenerateContentRealtimeInput`. However:

- Ordering across streams is not guaranteed.
- The server optimizes for best response but provides no ordering guarantees.
- For precise control, send content sequentially via `BidiGenerateContentClientContent`.
