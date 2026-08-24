# Function Calling

The Gemini Live API supports function calling (tool use), allowing the model to request execution of client-side functions during conversations.

## Overview

Function calling in the Live API differs from the standard Gemini API:

- Functions are invoked through dedicated message types, not Content parts.
- The model sends `BidiGenerateContentToolCall` messages.
- The client responds with `BidiGenerateContentToolResponse` messages.
- Functions can be canceled if the user interrupts.

## Defining Functions

Functions are defined in the session setup using OpenAPI-style schemas:

```json
{
  "tools": [
    {
      "functionDeclarations": [
        {
          "name": "get_weather",
          "description": "Get the current weather for a location",
          "parameters": {
            "type": "object",
            "properties": {
              "location": {
                "type": "string",
                "description": "The city and state, e.g., San Francisco, CA"
              },
              "unit": {
                "type": "string",
                "enum": ["celsius", "fahrenheit"],
                "description": "Temperature unit"
              }
            },
            "required": ["location"]
          }
        }
      ]
    }
  ]
}
```

## Function Declaration Schema

```json
{
  "name": "string",
  "description": "string",
  "parameters": {
    "type": "object",
    "properties": {
      "param_name": {
        "type": "string | integer | number | boolean | array | object",
        "description": "string",
        "enum": ["optional", "allowed", "values"]
      }
    },
    "required": ["array", "of", "required", "params"]
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Function identifier (alphanumeric + underscores). |
| `description` | string | Yes | Clear description of what the function does. |
| `parameters` | object | Yes | JSON Schema for function parameters. |
| `parameters.type` | string | Yes | Always `"object"` for the root. |
| `parameters.properties` | object | Yes | Parameter definitions. |
| `parameters.required` | array | No | List of required parameter names. |

## Receiving Function Calls

The server sends `BidiGenerateContentToolCall` when it wants to execute a function:

```json
{
  "toolCall": {
    "functionCalls": [
      {
        "id": "call_abc123",
        "name": "get_weather",
        "args": {
          "location": "San Francisco, CA",
          "unit": "fahrenheit"
        }
      }
    ]
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier for this call. Must be included in response. |
| `name` | string | Name of the function to execute. |
| `args` | object | Arguments to pass to the function. |


## Responding to Function Calls

Send a `BidiGenerateContentToolResponse` with the function result:

```json
{
  "toolResponse": {
    "functionResponses": [
      {
        "id": "call_abc123",
        "name": "get_weather",
        "response": {
          "temperature": 72,
          "conditions": "sunny",
          "humidity": 45
        }
      }
    ]
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Must match the `id` from the function call. |
| `name` | string | Function name (for clarity). |
| `response` | object | The function's return value. |

## Function Call Cancellation

If the user interrupts during function execution, the server sends:

```json
{
  "toolCallCancellation": {
    "ids": ["call_abc123"]
  }
}
```

When you receive a cancellation:

1. Stop executing the function if possible.
2. Do not send a response for canceled calls.
3. Discard any pending results.

## Python Example

```python
from google import genai
from google.genai.types import (
    LiveConnectConfig,
    Modality,
    Tool,
    FunctionDeclaration,
)

# Define the function
weather_function = FunctionDeclaration(
    name="get_weather",
    description="Get the current weather for a location",
    parameters={
        "type": "object",
        "properties": {
            "location": {
                "type": "string",
                "description": "The city and state"
            }
        },
        "required": ["location"]
    }
)

config = LiveConnectConfig(
    response_modalities=[Modality.TEXT],
    tools=[Tool(function_declarations=[weather_function])],
)

async def handle_session(session):
    # Send user message
    await session.send_client_content(
        turns=[{
            "role": "user",
            "parts": [{"text": "What's the weather in New York?"}]
        }]
    )

    async for message in session.receive():
        # Handle function call
        if message.tool_call:
            for call in message.tool_call.function_calls:
                if call.name == "get_weather":
                    # Execute the function
                    result = get_weather(call.args["location"])

                    # Send the response
                    await session.send_tool_response(
                        function_responses=[{
                            "id": call.id,
                            "name": call.name,
                            "response": result
                        }]
                    )

        # Handle text response
        if message.text:
            print(message.text)

        # Handle cancellation
        if message.tool_call_cancellation:
            print(f"Calls canceled: {message.tool_call_cancellation.ids}")

def get_weather(location: str) -> dict:
    # Your actual weather API call here
    return {
        "temperature": 72,
        "conditions": "sunny"
    }
```

## JavaScript Example

```javascript
const tools = [
  {
    functionDeclarations: [
      {
        name: 'get_weather',
        description: 'Get the current weather for a location',
        parameters: {
          type: 'object',
          properties: {
            location: {
              type: 'string',
              description: 'The city and state',
            },
          },
          required: ['location'],
        },
      },
    ],
  },
];

const config = {
  responseModalities: ['TEXT'],
  tools: tools,
};

session.on('message', async (msg) => {
  if (msg.toolCall) {
    for (const call of msg.toolCall.functionCalls) {
      if (call.name === 'get_weather') {
        const result = await getWeather(call.args.location);

        await session.sendToolResponse({
          functionResponses: [
            {
              id: call.id,
              name: call.name,
              response: result,
            },
          ],
        });
      }
    }
  }

  if (msg.toolCallCancellation) {
    console.log('Calls canceled:', msg.toolCallCancellation.ids);
  }
});

async function getWeather(location) {
  return {
    temperature: 72,
    conditions: 'sunny',
  };
}
```

## Multiple Functions

Define multiple functions in the tools array:

```json
{
  "tools": [
    {
      "functionDeclarations": [
        {
          "name": "get_weather",
          "description": "Get current weather",
          "parameters": { ... }
        },
        {
          "name": "search_products",
          "description": "Search for products",
          "parameters": { ... }
        },
        {
          "name": "create_order",
          "description": "Create a new order",
          "parameters": { ... }
        }
      ]
    }
  ]
}
```

## Parallel Function Calls

The model may request multiple functions in a single message:

```json
{
  "toolCall": {
    "functionCalls": [
      {
        "id": "call_1",
        "name": "get_weather",
        "args": { "location": "New York" }
      },
      {
        "id": "call_2",
        "name": "get_weather",
        "args": { "location": "Los Angeles" }
      }
    ]
  }
}
```

Respond with all results:

```json
{
  "toolResponse": {
    "functionResponses": [
      {
        "id": "call_1",
        "response": { "temperature": 65 }
      },
      {
        "id": "call_2",
        "response": { "temperature": 78 }
      }
    ]
  }
}
```

## Built-in Tools

### Google Search

Enable search grounding:

```json
{
  "tools": [
    {
      "googleSearch": {}
    }
  ]
}
```

Search results appear in `groundingMetadata`:

```json
{
  "serverContent": {
    "groundingMetadata": {
      "searchEntryPoint": { ... },
      "groundingChunks": [ ... ],
      "webSearchQueries": ["query1", "query2"]
    }
  }
}
```

### Code Execution

Enable code execution:

```json
{
  "tools": [
    {
      "codeExecution": {}
    }
  ]
}
```

## Limitations

1. **Audio impacts reliability**: Function calling is less reliable when using audio input/output compared to text-only interactions.

2. **No manual endpointing**: Cannot manually trigger function execution; relies on model's judgment.

3. **Cancellation timing**: Functions may be partially executed before cancellation arrives.

4. **Session resumption**: Session cannot be resumed during active function execution.


## Best Practices

1. **Clear descriptions**: Write detailed function descriptions so the model knows when to use them.

2. **Validate inputs**: Always validate function arguments before execution.

3. **Handle errors gracefully**: Return error information in the response rather than throwing exceptions.

4. **Implement timeouts**: Don't let function execution block indefinitely.

5. **Idempotent functions**: Where possible, make functions idempotent in case of retries.

6. **Minimize side effects**: Avoid functions with irreversible side effects during voice conversations.

```python
# Good: Return error in response
async def handle_function(call):
    try:
        result = execute_function(call.args)
        return {"success": True, "data": result}
    except Exception as e:
        return {"success": False, "error": str(e)}
```
