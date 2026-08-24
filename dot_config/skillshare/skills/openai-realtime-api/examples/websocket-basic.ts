/**
 * Basic WebSocket connection to OpenAI Realtime API.
 *
 * This example demonstrates:
 * - Establishing a WebSocket connection
 * - Configuring the session
 * - Sending and receiving events
 * - Basic audio handling
 */

import WebSocket from 'ws';

const OPENAI_API_KEY = process.env.OPENAI_API_KEY!;
const MODEL = 'gpt-realtime';

interface RealtimeEvent {
  type: string;
  event_id?: string;
  [key: string]: unknown;
}

class RealtimeClient {
  private ws: WebSocket | null = null;
  private currentItemId: string | null = null;

  async connect(): Promise<void> {
    const url = `wss://api.openai.com/v1/realtime?model=${MODEL}`;

    this.ws = new WebSocket(url, {
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        'OpenAI-Beta': 'realtime=v1',
      },
    });

    return new Promise((resolve, reject) => {
      this.ws!.on('open', () => {
        console.log('Connected to OpenAI Realtime API');
        this.configureSession();
        resolve();
      });

      this.ws!.on('error', (error) => {
        console.error('WebSocket error:', error);
        reject(error);
      });

      this.ws!.on('message', (data) => {
        const event = JSON.parse(data.toString()) as RealtimeEvent;
        this.handleEvent(event);
      });

      this.ws!.on('close', () => {
        console.log('Disconnected from OpenAI Realtime API');
      });
    });
  }

  private configureSession(): void {
    this.sendEvent({
      type: 'session.update',
      session: {
        type: 'realtime',
        instructions:
          'You are a helpful voice assistant. Be concise and friendly.',
        output_modalities: ['audio'],
        audio: {
          input: {
            format: { type: 'audio/pcm', rate: 24000 },
            transcription: { model: 'gpt-4o-mini-transcribe' },
            turn_detection: {
              type: 'semantic_vad',
              create_response: true,
              interrupt_response: true,
            },
          },
          output: {
            format: { type: 'audio/pcm', rate: 24000 },
            voice: 'alloy',
            speed: 1,
          },
        },
      },
    });
  }

  private handleEvent(event: RealtimeEvent): void {
    switch (event.type) {
      case 'session.created':
        console.log('Session created');
        break;

      case 'session.updated':
        console.log('Session configured');
        break;

      case 'conversation.item.added':
        console.log('Item added:', (event.item as { type: string }).type);
        break;

      case 'input_audio_buffer.speech_started':
        console.log('User started speaking');
        break;

      case 'input_audio_buffer.speech_stopped':
        console.log('User stopped speaking');
        break;

      case 'conversation.item.input_audio_transcription.completed':
        console.log('User said:', event.transcript);
        break;

      case 'response.created':
        console.log('Response started');
        break;

      case 'response.output_audio.delta':
        // Audio chunk received (base64 encoded).
        this.currentItemId = event.item_id as string;
        this.handleAudioDelta(event.delta as string);
        break;

      case 'response.output_audio_transcript.delta':
        // Transcript of the assistant's speech.
        process.stdout.write(event.delta as string);
        break;

      case 'response.output_audio_transcript.done':
        console.log('\nAssistant finished speaking');
        break;

      case 'response.done':
        console.log('Response completed');
        this.logUsage(event);
        break;

      case 'error':
        console.error('Error:', event.error);
        break;

      default:
        // Handle unknown events gracefully.
        break;
    }
  }

  private handleAudioDelta(base64Audio: string): void {
    // Convert base64 to buffer.
    const audioBuffer = Buffer.from(base64Audio, 'base64');

    // In a real application, stream this to speakers.
    // For demonstration, just log the chunk size.
    console.log(`Audio chunk: ${audioBuffer.length} bytes`);
  }

  private logUsage(event: RealtimeEvent): void {
    const response = event.response as {
      usage?: {
        input_tokens?: number;
        output_tokens?: number;
      };
    };
    if (response?.usage) {
      console.log('Token usage:', response.usage);
    }
  }

  sendEvent(event: Record<string, unknown>): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error('WebSocket is not connected');
    }
    this.ws.send(JSON.stringify(event));
  }

  /**
   * Send audio data to the API.
   * Audio should be PCM16 at 24kHz.
   */
  sendAudio(audioBuffer: Buffer): void {
    const base64Audio = audioBuffer.toString('base64');
    this.sendEvent({
      type: 'input_audio_buffer.append',
      audio: base64Audio,
    });
  }

  /**
   * Commit the audio buffer (for manual turn detection).
   */
  commitAudio(): void {
    this.sendEvent({
      type: 'input_audio_buffer.commit',
    });
  }

  /**
   * Send a text message.
   */
  sendTextMessage(text: string): void {
    this.sendEvent({
      type: 'conversation.item.create',
      item: {
        type: 'message',
        role: 'user',
        content: [{ type: 'input_text', text }],
      },
    });

    // Trigger a response.
    this.sendEvent({
      type: 'response.create',
    });
  }

  /**
   * Interrupt the current response.
   */
  interrupt(): void {
    // Cancel any ongoing response.
    this.sendEvent({
      type: 'response.cancel',
    });

    // Truncate the audio if we have a current item.
    if (this.currentItemId) {
      this.sendEvent({
        type: 'conversation.item.truncate',
        item_id: this.currentItemId,
        content_index: 0,
        audio_end_ms: 0,
      });
    }
  }

  disconnect(): void {
    this.ws?.close();
  }
}

// Main entry point.
async function main() {
  const client = new RealtimeClient();

  try {
    await client.connect();

    // Send a text message to test the connection.
    console.log('\nSending test message...');
    client.sendTextMessage('Hello! What can you help me with today?');

    // Keep the connection open.
    // In a real app, you would handle audio I/O here.
    await new Promise((resolve) => setTimeout(resolve, 30000));
  } catch (error) {
    console.error('Failed to connect:', error);
  } finally {
    client.disconnect();
  }
}

main();
