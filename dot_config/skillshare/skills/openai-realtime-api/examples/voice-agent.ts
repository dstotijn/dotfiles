/**
 * Complete voice agent implementation using the OpenAI Agents SDK.
 *
 * This example demonstrates:
 * - Creating a RealtimeAgent with tools
 * - Setting up a RealtimeSession
 * - Handling events and tool calls
 * - Agent handoffs
 * - Error handling
 */

import { tool } from '@openai/agents-core';
import {
  RealtimeAgent,
  RealtimeSession,
  RealtimeItem,
} from '@openai/agents-realtime';
import { z } from 'zod';

// Define tools for the agent.
const getWeatherTool = tool({
  name: 'get_weather',
  description: 'Get the current weather for a location',
  parameters: z.object({
    location: z.string().describe('City name, e.g., "San Francisco"'),
    unit: z
      .enum(['celsius', 'fahrenheit'])
      .optional()
      .describe('Temperature unit'),
  }),
  execute: async (args) => {
    // Simulate weather API call.
    const weather = {
      location: args.location,
      temperature: Math.round(Math.random() * 30 + 10),
      unit: args.unit || 'celsius',
      condition: ['sunny', 'cloudy', 'rainy'][Math.floor(Math.random() * 3)],
    };
    return JSON.stringify(weather);
  },
});

const searchProductsTool = tool({
  name: 'search_products',
  description: 'Search for products in the catalog',
  parameters: z.object({
    query: z.string().describe('Search query'),
    category: z
      .string()
      .optional()
      .describe('Product category to filter by'),
    maxPrice: z.number().optional().describe('Maximum price'),
  }),
  execute: async (args) => {
    // Simulate product search.
    const products = [
      { name: 'Widget A', price: 29.99, category: 'electronics' },
      { name: 'Widget B', price: 49.99, category: 'electronics' },
      { name: 'Gadget X', price: 99.99, category: 'gadgets' },
    ];

    const filtered = products.filter((p) => {
      if (args.category && p.category !== args.category) return false;
      if (args.maxPrice && p.price > args.maxPrice) return false;
      return true;
    });

    return JSON.stringify({ results: filtered, total: filtered.length });
  },
});

// Create a support agent for technical issues.
const supportAgent = new RealtimeAgent({
  name: 'support-agent',
  instructions: `You are a technical support specialist.
    - Help users troubleshoot technical issues
    - Be patient and thorough in your explanations
    - Ask clarifying questions when needed
    - Escalate complex issues appropriately`,
  voice: 'sage',
});

// Create a sales agent for product inquiries.
const salesAgent = new RealtimeAgent({
  name: 'sales-agent',
  instructions: `You are a sales assistant.
    - Help users find products that meet their needs
    - Provide pricing and availability information
    - Make product recommendations based on user preferences
    - Be helpful but not pushy`,
  voice: 'coral',
  tools: [searchProductsTool],
  handoffs: [supportAgent], // Can transfer to support.
});

// Create the main triage agent.
const triageAgent = new RealtimeAgent({
  name: 'triage-agent',
  instructions: `You are a friendly customer service representative.
    - Greet customers warmly
    - Determine if they need sales help or technical support
    - For product questions, pricing, or purchases, hand off to sales
    - For technical issues or troubleshooting, hand off to support
    - You can also answer general questions about the weather`,
  voice: 'alloy',
  tools: [getWeatherTool],
  handoffs: [salesAgent, supportAgent],
});

// Custom context type for tracking user information.
type UserContext = {
  userId: string;
  userName: string;
  preferredLanguage: string;
};

async function createVoiceAgent() {
  // Create the session with the triage agent.
  const session = new RealtimeSession<UserContext>(triageAgent, {
    transport: 'websocket',
    model: 'gpt-realtime',
    context: {
      userId: 'user-123',
      userName: 'Alice',
      preferredLanguage: 'en',
    },
    config: {
      outputModalities: ['audio'],
      audio: {
        input: {
          format: { type: 'audio/pcm', rate: 24000 },
          transcription: { model: 'gpt-4o-mini-transcribe' },
          turnDetection: {
            type: 'semantic_vad',
            eagerness: 'medium',
            interruptResponse: true,
          },
          noiseReduction: { type: 'near_field' },
        },
        output: {
          format: { type: 'audio/pcm', rate: 24000 },
          speed: 1,
        },
      },
    },
    historyStoreAudio: false, // Save memory by not storing audio.
    tracingDisabled: false,
    workflowName: 'customer-service-voice-agent',
  });

  // Set up event handlers.
  setupEventHandlers(session);

  return session;
}

function setupEventHandlers(session: RealtimeSession<UserContext>) {
  // Agent lifecycle events.
  session.on('agent_start', (context, agent) => {
    console.log(`\n🎙️ Agent "${agent.name}" is now active`);
  });

  session.on('agent_end', (context, agent, output) => {
    console.log(`\n📝 Agent "${agent.name}" said: ${output.substring(0, 100)}...`);
  });

  session.on('agent_handoff', (context, fromAgent, toAgent) => {
    console.log(`\n🔄 Handoff: ${fromAgent.name} → ${toAgent.name}`);
  });

  // Audio events.
  session.on('audio_start', () => {
    console.log('\n🔊 Audio output started');
  });

  session.on('audio', (event) => {
    // Process audio chunks.
    // In a real app, stream this to speakers or a WebRTC connection.
    process.stdout.write('.');
  });

  session.on('audio_stopped', () => {
    console.log('\n🔇 Audio output stopped');
  });

  session.on('audio_interrupted', () => {
    console.log('\n⚡ Audio interrupted by user');
  });

  // Tool events.
  session.on('agent_tool_start', (context, agent, tool, { toolCall }) => {
    console.log(`\n🔧 Tool call: ${tool.name}(${toolCall.arguments})`);
  });

  session.on('agent_tool_end', (context, agent, tool, result) => {
    console.log(`\n✅ Tool result: ${result.substring(0, 100)}...`);
  });

  // Tool approval events.
  session.on('tool_approval_requested', async (context, agent, request) => {
    if (request.type === 'function_approval') {
      console.log(`\n⚠️ Tool "${request.tool.name}" requires approval`);
      // In a real app, show UI for approval.
      // For demo, auto-approve.
      await session.approve(request.approvalItem);
    }
  });

  // History events.
  session.on('history_updated', (history: RealtimeItem[]) => {
    console.log(`\n📚 History updated: ${history.length} items`);
  });

  session.on('history_added', (item: RealtimeItem) => {
    if (item.type === 'message') {
      const content = item.content[0];
      if ('text' in content && content.text) {
        const preview = content.text.substring(0, 50);
        console.log(`\n📩 New ${item.role} message: ${preview}...`);
      } else if ('transcript' in content && content.transcript) {
        const preview = content.transcript.substring(0, 50);
        console.log(`\n📩 New ${item.role} audio: ${preview}...`);
      }
    }
  });

  // Guardrail events.
  session.on('guardrail_tripped', (context, agent, error) => {
    console.log(`\n🛑 Guardrail triggered: ${error.message}`);
  });

  // MCP events.
  session.on('mcp_tools_changed', (tools) => {
    console.log(`\n🔌 MCP tools available: ${tools.map((t) => t.name).join(', ')}`);
  });

  session.on('mcp_tool_call_completed', (context, agent, toolCall) => {
    console.log(`\n🔌 MCP tool completed: ${toolCall.name}`);
  });

  // Error handling.
  session.on('error', (error) => {
    console.error('\n❌ Session error:', error);
  });

  // Transport events (raw API events).
  session.on('transport_event', (event) => {
    // Uncomment to see all raw events.
    // console.log('Raw event:', event.type);
  });
}

async function main() {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    console.error('Please set OPENAI_API_KEY environment variable');
    process.exit(1);
  }

  console.log('🚀 Starting voice agent...\n');

  const session = await createVoiceAgent();

  try {
    // Connect to the API.
    await session.connect({ apiKey });
    console.log('✅ Connected to OpenAI Realtime API\n');

    // Send an initial greeting.
    session.sendMessage(
      'Hello! I just connected. Please greet me and ask how you can help.'
    );

    // Keep the session running.
    // In a real app, you would:
    // 1. Capture audio from microphone.
    // 2. Send audio via session.sendAudio().
    // 3. Play received audio through speakers.
    // 4. Handle user interactions (mute, hang up, etc.).

    console.log('\n⏳ Session active. Press Ctrl+C to disconnect.\n');

    // Simulate a conversation flow.
    await new Promise<void>((resolve) => {
      setTimeout(() => {
        // Simulate user asking about weather.
        console.log('\n📤 Simulating user message about weather...');
        session.sendMessage("What's the weather like in San Francisco?");
      }, 5000);

      setTimeout(() => {
        // Simulate user asking about products.
        console.log('\n📤 Simulating user message about products...');
        session.sendMessage(
          "I'm looking for some electronics under $50. Can you help?"
        );
      }, 15000);

      setTimeout(() => {
        console.log('\n⏰ Demo complete');
        resolve();
      }, 30000);
    });
  } catch (error) {
    console.error('Failed to run voice agent:', error);
  } finally {
    // Clean up.
    console.log('\n👋 Disconnecting...');
    session.close();

    // Log final usage.
    const usage = session.usage;
    console.log('\n📊 Total usage:');
    console.log(`   Input tokens:  ${usage.inputTokens}`);
    console.log(`   Output tokens: ${usage.outputTokens}`);
    console.log(`   Total tokens:  ${usage.totalTokens}`);
  }
}

main();
