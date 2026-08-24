# Voice Configuration

The Gemini Live API supports 30 HD voices powered by Chirp 3 and 24 languages for natural, realistic speech output.

## Available Voices

| Voice Name | Characteristic | Description |
|------------|----------------|-------------|
| Zephyr | Bright | Energetic and clear |
| Puck | Upbeat | Friendly and enthusiastic |
| Charon | Informative | Clear and authoritative |
| Kore | Firm | Confident and direct |
| Fenrir | Excitable | Animated and expressive |
| Leda | Youthful | Young and fresh |
| Enceladus | Breathy | Soft and intimate |
| Algieba | Smooth | Flowing and polished |
| Aoede | Breezy | Light and casual |
| Autonoe | Bright | Vibrant and lively |
| Erinome | Bright | Cheerful and positive |
| Orus | Firm | Steady and reliable |
| Alnilam | Firm | Strong and decisive |
| Umbriel | Easy-going | Relaxed and approachable |
| Callirrhoe | Easy-going | Calm and friendly |
| Schedar | Clear | Precise and articulate |
| Iapetus | Clear | Clean and intelligible |
| Achird | Friendly | Warm and welcoming |
| Laomedeia | Upbeat | Positive and engaging |
| Algenib | Gravelly | Deep and textured |
| Achernar | Soft | Gentle and soothing |
| Gacrux | Mature | Experienced and wise |
| Zubenelgenubi | Casual | Relaxed and informal |
| Sadaltager | Knowledgeable | Informed and thoughtful |
| Despina | Smooth | Even and refined |
| Rasalgethi | Informative | Educational and clear |
| Pulcherrima | Forward | Direct and confident |
| Vindemiatrix | Gentle | Kind and caring |
| Sulafat | Warm | Friendly and comforting |
| Sadachbia | Lively | Dynamic and spirited |

## Supported Languages

| Language | Code | Native Name |
|----------|------|-------------|
| English (US) | en-US | English |
| English (India) | en-IN | English |
| Spanish (US) | es-US | Español |
| French | fr-FR | Français |
| German | de-DE | Deutsch |
| Japanese | ja-JP | 日本語 |
| Korean | ko-KR | 한국어 |
| Portuguese (Brazil) | pt-BR | Português |
| Hindi | hi-IN | हिन्दी |
| Arabic (Egyptian) | ar-EG | العربية |
| Bengali | bn-IN | বাংলা |
| Dutch | nl-NL | Nederlands |
| Indonesian | id-ID | Bahasa Indonesia |
| Italian | it-IT | Italiano |
| Marathi | mr-IN | मराठी |
| Polish | pl-PL | Polski |
| Romanian | ro-RO | Română |
| Russian | ru-RU | Русский |
| Tamil | ta-IN | தமிழ் |
| Telugu | te-IN | తెలుగు |
| Thai | th-TH | ไทย |
| Turkish | tr-TR | Türkçe |
| Ukrainian | uk-UA | Українська |
| Vietnamese | vi-VN | Tiếng Việt |

## Configuration

### Basic Voice Configuration

```json
{
  "generationConfig": {
    "speechConfig": {
      "voiceConfig": {
        "prebuiltVoiceConfig": {
          "voiceName": "Puck"
        }
      }
    }
  }
}
```

### Voice with Language

```json
{
  "generationConfig": {
    "speechConfig": {
      "voiceConfig": {
        "prebuiltVoiceConfig": {
          "voiceName": "Kore"
        }
      },
      "languageCode": "en-US"
    }
  }
}
```

## Python Example

```python
from google.genai.types import (
    LiveConnectConfig,
    Modality,
    SpeechConfig,
    VoiceConfig,
    PrebuiltVoiceConfig,
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
)
```

## JavaScript Example

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
};
```

## Language Behavior

### Standard Models (gemini-live-2.5-flash)

- Language configured via `speechConfig.languageCode`.
- Model outputs in the specified language.
- Voice selected via `voiceName` field.

### Native Audio Models (gemini-live-2.5-flash-native-audio)

- Can switch between languages naturally during conversation.
- Automatically detects and responds in the user's language.
- Restrict languages via system instructions if needed.

### Restricting Languages

For native audio models, use system instructions to limit language switching:

```python
config = LiveConnectConfig(
    response_modalities=[Modality.AUDIO],
    system_instruction="Always respond in English only. Do not switch to other languages.",
    speech_config=SpeechConfig(
        voice_config=VoiceConfig(
            prebuilt_voice_config=PrebuiltVoiceConfig(
                voice_name="Charon"
            )
        ),
    ),
)
```

## Affective Dialog

Native audio models support affective dialog, adapting response style and tone to match user expression.

### Enabling Affective Dialog

Requires API version `v1alpha`:

```python
from google.genai.types import LiveConnectConfig, Modality

config = LiveConnectConfig(
    response_modalities=[Modality.AUDIO],
    enable_affective_dialog=True,
    speech_config=SpeechConfig(
        voice_config=VoiceConfig(
            prebuilt_voice_config=PrebuiltVoiceConfig(
                voice_name="Aoede"
            )
        ),
    ),
)
```

With affective dialog:

- Model adapts tone to user's emotional state.
- Responses feel more natural and empathetic.
- Voice characteristics dynamically adjust.

## Voice Selection Tips

### For Customer Service

- **Charon** or **Rasalgethi**: Informative and clear.
- **Kore** or **Orus**: Professional and confident.

### For Casual Conversations

- **Puck** or **Achird**: Friendly and approachable.
- **Umbriel** or **Zubenelgenubi**: Relaxed and easy-going.

### For Educational Content

- **Sadaltager**: Knowledgeable and thoughtful.
- **Schedar** or **Iapetus**: Clear and precise.

### For Entertainment

- **Fenrir**: Excitable and animated.
- **Sadachbia** or **Laomedeia**: Lively and engaging.

### For Sensitive Topics

- **Vindemiatrix** or **Sulafat**: Gentle and warm.
- **Achernar**: Soft and soothing.

## Voice Consistency

The same voice name produces consistent voice characteristics across sessions. However, with affective dialog enabled, the tone and delivery may vary based on conversation context.

## Testing Voices

Demo each voice in Google AI Studio to find the best fit for your application:
- [Google AI Studio Live API](https://aistudio.google.com/live)
