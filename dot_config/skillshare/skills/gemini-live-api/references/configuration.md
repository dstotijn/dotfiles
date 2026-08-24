# Configuration

Session configuration is sent in the initial `BidiGenerateContentSetup` message and cannot be changed during the session. To modify configuration, you must close the session and create a new one.

## Session Configuration

```json
{
  "model": "gemini-2.5-flash-native-audio-preview-12-2025",
  "generationConfig": {
    "responseModalities": ["AUDIO"],
    "temperature": 1.0,
    "topP": 0.95,
    "topK": 40,
    "maxOutputTokens": 8192,
    "candidateCount": 1,
    "presencePenalty": 0.0,
    "frequencyPenalty": 0.0,
    "speechConfig": {},
    "mediaResolution": "MEDIA_RESOLUTION_MEDIUM"
  },
  "systemInstruction": "You are a helpful assistant.",
  "tools": [],
  "realtimeInputConfig": {},
  "sessionResumption": {},
  "contextWindowCompression": {},
  "inputAudioTranscription": {},
  "outputAudioTranscription": {}
}
```

## Generation Config

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `responseModalities` | array | `["TEXT"]` | `TEXT`, `AUDIO` | Output types. Cannot use both simultaneously. |
| `temperature` | float | 1.0 | 0.0 - 2.0 | Controls randomness in output. |
| `topP` | float | 0.95 | 0.0 - 1.0 | Nucleus sampling threshold. |
| `topK` | integer | 40 | 1 - 100 | Top-K sampling parameter. |
| `maxOutputTokens` | integer | Model-dependent | - | Maximum response length in tokens. |
| `candidateCount` | integer | 1 | 1 | Number of response variants (only 1 supported). |
| `presencePenalty` | float | 0.0 | -2.0 - 2.0 | Penalty for token presence. |
| `frequencyPenalty` | float | 0.0 | -2.0 - 2.0 | Penalty for token frequency. |

## Speech Config

Configure voice output characteristics:

```json
{
  "speechConfig": {
    "voiceConfig": {
      "prebuiltVoiceConfig": {
        "voiceName": "Puck"
      }
    },
    "languageCode": "en-US"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `voiceConfig.prebuiltVoiceConfig.voiceName` | string | Name of the prebuilt voice to use. |
| `languageCode` | string | BCP-47 language code for speech output. |

See [Voice Configuration](./voice-configuration.md) for available voices and languages.

## Realtime Input Config

Configure voice activity detection and input handling:

```json
{
  "realtimeInputConfig": {
    "automaticActivityDetection": {
      "disabled": false,
      "startOfSpeechSensitivity": "START_SENSITIVITY_HIGH",
      "prefixPaddingMs": 300,
      "endOfSpeechSensitivity": "END_SENSITIVITY_HIGH",
      "silenceDurationMs": 1000
    },
    "activityHandling": "START_OF_ACTIVITY_INTERRUPTS",
    "turnCoverage": "TURN_INCLUDES_ONLY_ACTIVITY"
  }
}
```

### Automatic Activity Detection

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `disabled` | boolean | false | Disable automatic VAD. |
| `startOfSpeechSensitivity` | enum | - | `START_SENSITIVITY_LOW`, `START_SENSITIVITY_HIGH` |
| `prefixPaddingMs` | integer | - | Milliseconds of audio to include before speech start. |
| `endOfSpeechSensitivity` | enum | - | `END_SENSITIVITY_LOW`, `END_SENSITIVITY_HIGH` |
| `silenceDurationMs` | integer | - | Silence duration to trigger end of speech. |

### Activity Handling

| Value | Description |
|-------|-------------|
| `START_OF_ACTIVITY_INTERRUPTS` | User input interrupts model generation (default). |
| `NO_INTERRUPTION` | Model response continues despite user input. |

### Turn Coverage

| Value | Description |
|-------|-------------|
| `TURN_INCLUDES_ONLY_ACTIVITY` | Excludes silence from turn (default). |
| `TURN_INCLUDES_ALL_INPUT` | Includes all input including silence. |

## Context Window Compression

Manage context size with sliding window compression:

```json
{
  "contextWindowCompression": {
    "slidingWindow": {
      "targetTokens": 16000
    },
    "triggerTokens": 24000
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `slidingWindow.targetTokens` | integer | Target token count after compression. |
| `triggerTokens` | integer | Token count that triggers compression (default: 80% of context limit). |

## Session Resumption

Enable session resumption for long-running conversations:

```json
{
  "sessionResumption": {
    "handle": "previous_session_handle"
  }
}
```

The server sends `SessionResumptionUpdate` messages with new handles when the session is resumable. Resumption is not available during function execution or generation.

## Transcription Config

### Input Audio Transcription

```json
{
  "inputAudioTranscription": {
    "model": "gemini-2.0-flash"
  }
}
```

### Output Audio Transcription

```json
{
  "outputAudioTranscription": {}
}
```

Transcriptions are returned in `BidiGenerateContentServerContent.inputTranscription` and `BidiGenerateContentServerContent.outputTranscription`.

## System Instructions

Provide context and behavior guidelines:

```json
{
  "systemInstruction": "You are a friendly customer service agent for Acme Corp. Be helpful, concise, and professional. If you don't know something, say so."
}
```

Can also be provided as structured content:

```json
{
  "systemInstruction": {
    "parts": [
      {
        "text": "You are a helpful assistant."
      }
    ]
  }
}
```

## Media Resolution

Control video processing quality:

```json
{
  "generationConfig": {
    "mediaResolution": "MEDIA_RESOLUTION_MEDIUM"
  }
}
```

| Value | Description |
|-------|-------------|
| `MEDIA_RESOLUTION_LOW` | Lower quality, faster processing. |
| `MEDIA_RESOLUTION_MEDIUM` | Balanced quality and speed (default). |
| `MEDIA_RESOLUTION_HIGH` | Higher quality, slower processing. |

## Native Audio Features (Preview)

### Affective Dialog

Enable emotional response adaptation (requires API version `v1alpha`):

```json
{
  "generationConfig": {
    "enableAffectiveDialog": true
  }
}
```

### Proactive Audio

Allow model to decide not to respond when content is not relevant:

```json
{
  "generationConfig": {
    "proactiveAudio": true
  }
}
```

### Thinking

Configure model thinking capabilities:

```json
{
  "generationConfig": {
    "thinkingConfig": {
      "thinkingBudget": 1024,
      "includeThoughts": true
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `thinkingBudget` | integer | Token budget for thinking (0 to disable). |
| `includeThoughts` | boolean | Include thought summaries in response. |

## Python Configuration Example

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
    response_modalities=[Modality.AUDIO],
    speech_config=SpeechConfig(
        voice_config=VoiceConfig(
            prebuilt_voice_config=PrebuiltVoiceConfig(
                voice_name="Puck"
            )
        ),
        language_code="en-US",
    ),
    system_instruction="You are a helpful assistant.",
    realtime_input_config=RealtimeInputConfig(
        automatic_activity_detection=AutomaticActivityDetection(
            disabled=False,
            silence_duration_ms=1000,
        ),
    ),
)
```

## JavaScript Configuration Example

```javascript
const config = {
  responseModalities: ['AUDIO'],
  speechConfig: {
    voiceConfig: {
      prebuiltVoiceConfig: {
        voiceName: 'Puck',
      },
    },
    languageCode: 'en-US',
  },
  systemInstruction: 'You are a helpful assistant.',
  realtimeInputConfig: {
    automaticActivityDetection: {
      disabled: false,
      silenceDurationMs: 1000,
    },
  },
};
```
