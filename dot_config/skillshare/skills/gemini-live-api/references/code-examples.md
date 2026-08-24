# Code Examples

Complete implementation examples for the Gemini Live API in Python.

## Python

### Basic Text Conversation

```python
import asyncio
from google import genai
from google.genai.types import Content, LiveConnectConfig, Modality, Part

client = genai.Client(api_key="YOUR_API_KEY")
model_id = "gemini-2.5-flash-native-audio-preview-12-2025"

async def text_conversation():
    async with client.aio.live.connect(
        model=model_id,
        config=LiveConnectConfig(response_modalities=[Modality.TEXT]),
    ) as session:
        text_input = "Hello! Tell me a short joke."
        print(f"> {text_input}")

        await session.send_client_content(
            turns=Content(role="user", parts=[Part(text=text_input)])
        )

        response = []
        async for message in session.receive():
            if message.text:
                response.append(message.text)

        print("".join(response))

asyncio.run(text_conversation())
```

### Audio Streaming Conversation

```python
import asyncio
import base64
import pyaudio
from google import genai
from google.genai.types import (
    Blob,
    LiveConnectConfig,
    Modality,
    PrebuiltVoiceConfig,
    SpeechConfig,
    VoiceConfig,
)

# Audio configuration.
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
INPUT_RATE = 16000
OUTPUT_RATE = 24000

client = genai.Client(api_key="YOUR_API_KEY")
model_id = "gemini-2.5-flash-native-audio-preview-12-2025"

class AudioStreamer:
    def __init__(self):
        self.p = pyaudio.PyAudio()
        self.input_stream = None
        self.output_stream = None
        self.running = False

    def start(self):
        self.input_stream = self.p.open(
            format=FORMAT,
            channels=CHANNELS,
            rate=INPUT_RATE,
            input=True,
            frames_per_buffer=CHUNK
        )
        self.output_stream = self.p.open(
            format=FORMAT,
            channels=CHANNELS,
            rate=OUTPUT_RATE,
            output=True
        )
        self.running = True

    def stop(self):
        self.running = False
        if self.input_stream:
            self.input_stream.stop_stream()
            self.input_stream.close()
        if self.output_stream:
            self.output_stream.stop_stream()
            self.output_stream.close()
        self.p.terminate()

    def read_audio(self):
        return self.input_stream.read(CHUNK, exception_on_overflow=False)

    def play_audio(self, data):
        self.output_stream.write(data)

async def audio_conversation():
    streamer = AudioStreamer()
    streamer.start()

    config = LiveConnectConfig(
        response_modalities=[Modality.AUDIO],
        speech_config=SpeechConfig(
            voice_config=VoiceConfig(
                prebuilt_voice_config=PrebuiltVoiceConfig(voice_name="Puck")
            ),
            language_code="en-US",
        ),
    )

    try:
        async with client.aio.live.connect(
            model=model_id,
            config=config,
        ) as session:
            # Task to send audio.
            async def send_audio():
                while streamer.running:
                    data = streamer.read_audio()
                    await session.send_realtime_input(
                        media=Blob(mime_type="audio/pcm;rate=16000", data=data)
                    )
                    await asyncio.sleep(0.01)

            # Task to receive and play audio.
            async def receive_audio():
                async for message in session.receive():
                    if message.server_content and message.server_content.model_turn:
                        for part in message.server_content.model_turn.parts:
                            if part.inline_data:
                                audio_data = base64.b64decode(part.inline_data.data)
                                streamer.play_audio(audio_data)

                    if message.server_content and message.server_content.turn_complete:
                        print("Model turn complete.")

            # Run both tasks concurrently.
            await asyncio.gather(
                send_audio(),
                receive_audio(),
            )
    finally:
        streamer.stop()

asyncio.run(audio_conversation())
```

### Function Calling

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
model_id = "gemini-2.5-flash-native-audio-preview-12-2025"

# Define functions.
functions = [
    FunctionDeclaration(
        name="get_weather",
        description="Get current weather for a location",
        parameters={
            "type": "object",
            "properties": {
                "location": {
                    "type": "string",
                    "description": "City and state, e.g., San Francisco, CA"
                },
                "unit": {
                    "type": "string",
                    "enum": ["celsius", "fahrenheit"],
                    "description": "Temperature unit"
                }
            },
            "required": ["location"]
        }
    ),
    FunctionDeclaration(
        name="search_products",
        description="Search for products in the catalog",
        parameters={
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query"
                },
                "category": {
                    "type": "string",
                    "description": "Product category"
                }
            },
            "required": ["query"]
        }
    )
]

# Function implementations.
def get_weather(location: str, unit: str = "fahrenheit") -> dict:
    # Simulated weather data.
    return {
        "location": location,
        "temperature": 72 if unit == "fahrenheit" else 22,
        "unit": unit,
        "conditions": "sunny"
    }

def search_products(query: str, category: str = None) -> dict:
    # Simulated product search.
    return {
        "query": query,
        "results": [
            {"name": f"{query} Pro", "price": 99.99},
            {"name": f"{query} Basic", "price": 49.99}
        ]
    }

async def function_calling_example():
    config = LiveConnectConfig(
        response_modalities=[Modality.TEXT],
        tools=[Tool(function_declarations=functions)],
    )

    async with client.aio.live.connect(
        model=model_id,
        config=config,
    ) as session:
        # Send user message.
        await session.send_client_content(
            turns=[{
                "role": "user",
                "parts": [{"text": "What's the weather in New York?"}]
            }]
        )

        async for message in session.receive():
            # Handle function calls.
            if message.tool_call:
                responses = []
                for call in message.tool_call.function_calls:
                    print(f"Function call: {call.name}({call.args})")

                    if call.name == "get_weather":
                        result = get_weather(**call.args)
                    elif call.name == "search_products":
                        result = search_products(**call.args)
                    else:
                        result = {"error": f"Unknown function: {call.name}"}

                    responses.append({
                        "id": call.id,
                        "name": call.name,
                        "response": result
                    })

                await session.send_tool_response(function_responses=responses)

            # Handle text response.
            if message.text:
                print(f"Response: {message.text}")

            # Handle cancellation.
            if message.tool_call_cancellation:
                print(f"Canceled: {message.tool_call_cancellation.ids}")

asyncio.run(function_calling_example())
```

## JavaScript / Node.js

### Basic Text Conversation

```javascript
const { GoogleGenAI, Modality } = require('@google/genai');

const client = new GoogleGenAI({ apiKey: process.env.GOOGLE_API_KEY });
const modelId = 'gemini-2.5-flash-native-audio-preview-12-2025';

async function textConversation() {
  const responseQueue = [];

  const session = await client.live.connect({
    model: modelId,
    config: { responseModalities: [Modality.TEXT] },
    callbacks: {
      onmessage: (msg) => {
        if (msg.text) {
          responseQueue.push(msg.text);
        }
        if (msg.serverContent?.turnComplete) {
          console.log('Response:', responseQueue.join(''));
        }
      },
      onerror: (e) => console.error('Error:', e.message),
    },
  });

  console.log('> Hello! Tell me a short joke.');
  await session.sendClientContent({
    turns: [{ role: 'user', parts: [{ text: 'Hello! Tell me a short joke.' }] }],
  });

  // Wait for response.
  await new Promise(resolve => setTimeout(resolve, 5000));
  session.close();
}

textConversation();
```

### Audio Streaming Conversation

```javascript
const { GoogleGenAI, Modality } = require('@google/genai');
const mic = require('mic');
const Speaker = require('speaker');

const client = new GoogleGenAI({ apiKey: process.env.GOOGLE_API_KEY });
const modelId = 'gemini-2.5-flash-native-audio-preview-12-2025';

async function audioConversation() {
  // Setup microphone.
  const micInstance = mic({
    rate: '16000',
    channels: '1',
    bitwidth: '16',
    encoding: 'signed-integer',
  });
  const micInputStream = micInstance.getAudioStream();

  // Setup speaker.
  const speaker = new Speaker({
    channels: 1,
    bitDepth: 16,
    sampleRate: 24000,
  });

  const config = {
    responseModalities: [Modality.AUDIO],
    speechConfig: {
      voiceConfig: {
        prebuiltVoiceConfig: {
          voiceName: 'Puck',
        },
      },
      languageCode: 'en-US',
    },
  };

  const session = await client.live.connect({
    model: modelId,
    config,
    callbacks: {
      onmessage: (msg) => {
        if (msg.serverContent?.modelTurn?.parts) {
          for (const part of msg.serverContent.modelTurn.parts) {
            if (part.inlineData) {
              const audioBuffer = Buffer.from(part.inlineData.data, 'base64');
              speaker.write(audioBuffer);
            }
          }
        }
        if (msg.serverContent?.turnComplete) {
          console.log('Model turn complete.');
        }
      },
      onerror: (e) => console.error('Error:', e.message),
    },
  });

  // Send audio from microphone.
  micInputStream.on('data', (data) => {
    const base64Audio = data.toString('base64');
    session.sendRealtimeInput({ audio: base64Audio });
  });

  micInstance.start();
  console.log('Listening... Press Ctrl+C to stop');

  // Handle shutdown.
  process.on('SIGINT', () => {
    micInstance.stop();
    session.close();
    process.exit();
  });
}

audioConversation();
```

### Function Calling

```javascript
const { GoogleGenAI, Modality } = require('@google/genai');

const client = new GoogleGenAI({ apiKey: process.env.GOOGLE_API_KEY });
const modelId = 'gemini-2.5-flash-native-audio-preview-12-2025';

const tools = [
  {
    functionDeclarations: [
      {
        name: 'get_weather',
        description: 'Get current weather for a location',
        parameters: {
          type: 'object',
          properties: {
            location: {
              type: 'string',
              description: 'City and state, e.g., San Francisco, CA',
            },
          },
          required: ['location'],
        },
      },
    ],
  },
];

// Function implementations.
function getWeather(location) {
  return {
    location,
    temperature: 72,
    conditions: 'sunny',
  };
}

async function functionCallingExample() {
  const session = await client.live.connect({
    model: modelId,
    config: {
      responseModalities: [Modality.TEXT],
      tools,
    },
    callbacks: {
      onmessage: async (msg) => {
        // Handle function calls.
        if (msg.toolCall) {
          const responses = [];
          for (const call of msg.toolCall.functionCalls) {
            console.log(`Function call: ${call.name}(${JSON.stringify(call.args)})`);

            let result;
            if (call.name === 'get_weather') {
              result = getWeather(call.args.location);
            } else {
              result = { error: `Unknown function: ${call.name}` };
            }

            responses.push({
              id: call.id,
              name: call.name,
              response: result,
            });
          }

          await session.sendToolResponse({ functionResponses: responses });
        }

        // Handle text response.
        if (msg.text) {
          console.log('Response:', msg.text);
        }
      },
      onerror: (e) => console.error('Error:', e.message),
    },
  });

  console.log('> What\'s the weather in New York?');
  await session.sendClientContent({
    turns: [{ role: 'user', parts: [{ text: "What's the weather in New York?" }] }],
  });

  await new Promise(resolve => setTimeout(resolve, 10000));
  session.close();
}

functionCallingExample();
```

## Connection Wrapper Pattern (from adk-python)

A robust connection wrapper based on the [adk-python](https://github.com/google/adk-python) reference implementation:

```python
from google.genai import live, types
from typing import AsyncGenerator, Union

RealtimeInput = Union[types.Blob, types.ActivityStart, types.ActivityEnd]

class GeminiLlmConnection:
    """Wrapper for live.AsyncSession with transcription handling."""

    def __init__(self, session: live.AsyncSession):
        self._session = session
        self._input_transcription_text = ''
        self._output_transcription_text = ''

    async def send_history(self, history: list[types.Content]):
        """Send conversation history, filtering audio parts."""
        # Audio is already transcribed. Sending via send_client_content corrupts the session.
        contents = [
            filtered
            for content in history
            if (filtered := self._filter_audio_parts(content)) is not None
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

    async def receive(self) -> AsyncGenerator[dict, None]:
        """Receive and process model responses."""
        async for message in self._session.receive():
            # Handle transcriptions.
            if message.server_content:
                if message.server_content.input_transcription:
                    if message.server_content.input_transcription.text:
                        self._input_transcription_text += (
                            message.server_content.input_transcription.text
                        )
                    if message.server_content.input_transcription.finished:
                        yield {
                            'type': 'input_transcription',
                            'text': self._input_transcription_text,
                            'finished': True,
                        }
                        self._input_transcription_text = ''

                if message.server_content.output_transcription:
                    if message.server_content.output_transcription.text:
                        self._output_transcription_text += (
                            message.server_content.output_transcription.text
                        )
                    if message.server_content.output_transcription.finished:
                        yield {
                            'type': 'output_transcription',
                            'text': self._output_transcription_text,
                            'finished': True,
                        }
                        self._output_transcription_text = ''

                # Flush transcriptions on completion signals.
                if (message.server_content.turn_complete or
                    message.server_content.generation_complete or
                    message.server_content.interrupted):
                    if self._input_transcription_text:
                        yield {
                            'type': 'input_transcription',
                            'text': self._input_transcription_text,
                            'finished': True,
                        }
                        self._input_transcription_text = ''
                    if self._output_transcription_text:
                        yield {
                            'type': 'output_transcription',
                            'text': self._output_transcription_text,
                            'finished': True,
                        }
                        self._output_transcription_text = ''

                if message.server_content.turn_complete:
                    yield {'type': 'turn_complete'}
                    break

            # Handle tool calls.
            if message.tool_call:
                yield {
                    'type': 'tool_call',
                    'function_calls': message.tool_call.function_calls,
                }

    async def close(self):
        await self._session.close()

    def _filter_audio_parts(self, content: types.Content) -> types.Content | None:
        """Filter out audio parts from content."""
        if not content or not content.parts:
            return None

        filtered_parts = [
            part for part in content.parts
            if not (part.inline_data and part.inline_data.mime_type.startswith("audio/"))
        ]

        if not filtered_parts:
            return None

        return types.Content(role=content.role, parts=filtered_parts)
```
