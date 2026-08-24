# Event Flows

This document describes the event flows and state management patterns for the Gemini Live API, based on the [google/adk-python](https://github.com/google/adk-python) `GeminiLlmConnection` reference implementation.

## Core Receive Loop

The `receive()` method is an async generator that processes messages from the Live API. Understanding its structure is critical for correct implementation.

```python
async def receive(self) -> AsyncGenerator[LlmResponse, None]:
    text = ''  # Accumulates partial text responses
    async for message in self._session.receive():
        # 1. Usage metadata (yields separately)
        if message.usage_metadata:
            yield LlmResponse(usage_metadata=message.usage_metadata)

        # 2. Server content processing
        if message.server_content:
            # 2a. Model turn (text/audio chunks)
            # 2b. Input transcription
            # 2c. Output transcription
            # 2d. Transcription fallback flush (GEMINI_API only)
            # 2e. Turn complete → yield and BREAK
            # 2f. Interrupted (without turn_complete)

        # 3. Tool calls
        if message.tool_call:
            # Yields function calls as Content

        # 4. Session resumption
        if message.session_resumption_update:
            yield LlmResponse(live_session_resumption_update=...)
```

**Critical insight**: The loop **breaks** when `turn_complete` is received. You must call `receive()` again for the next turn.

## Message Processing Order

Within each message, adk-python processes fields in this order:

```
message received
    │
    ├─ 1. usage_metadata → yield token usage
    │
    ├─ 2. server_content
    │     ├─ model_turn → accumulate text or yield audio
    │     ├─ input_transcription → accumulate and yield
    │     ├─ output_transcription → accumulate and yield
    │     ├─ [GEMINI_API only] fallback flush on control events
    │     ├─ turn_complete → flush text, yield, BREAK
    │     └─ interrupted (if no turn_complete) → flush text, yield
    │
    ├─ 3. tool_call → flush text, yield function calls
    │
    └─ 4. session_resumption_update → yield handle
```

## Text Accumulation Pattern

The adk-python implementation accumulates partial text responses and emits them as complete responses at appropriate boundaries.

```python
text = ''  # Local accumulator

async for message in session.receive():
    if message.server_content:
        content = message.server_content.model_turn
        if content and content.parts:
            llm_response = LlmResponse(
                content=content,
                interrupted=message.server_content.interrupted
            )

            if content.parts[0].text:
                # Accumulate text, mark as partial.
                text += content.parts[0].text
                llm_response.partial = True

            elif text and not content.parts[0].inline_data:
                # Non-text, non-audio content: flush accumulated text first.
                yield build_full_text_response(text)
                text = ''

            yield llm_response

        # Flush on turn_complete.
        if message.server_content.turn_complete:
            if text:
                yield build_full_text_response(text)
                text = ''
            yield LlmResponse(
                turn_complete=True,
                interrupted=message.server_content.interrupted,
            )
            break  # Exit the receive loop.

        # Flush on interrupted (without turn_complete).
        if message.server_content.interrupted:
            if text:
                yield build_full_text_response(text)
                text = ''
            else:
                yield LlmResponse(interrupted=True)

    # Flush before tool calls.
    if message.tool_call:
        if text:
            yield build_full_text_response(text)
            text = ''
        # ... yield tool call ...
```

**Key behaviors**:
- Text chunks have `partial=True`
- Accumulated text is flushed on: turn_complete, interrupted, tool_call, or non-text/non-audio content
- The `partial` flag lets consumers know when text is complete

## Turn Completion

Turn completion is signaled by `server_content.turn_complete`. When received:

1. Any accumulated text is flushed as a complete response
2. An `LlmResponse(turn_complete=True)` is yielded
3. The receive loop **breaks**

```python
if message.server_content.turn_complete:
    if text:
        yield self.__build_full_text_response(text)
        text = ''
    yield LlmResponse(
        turn_complete=True,
        interrupted=message.server_content.interrupted,  # Can be True!
    )
    break
```

**Important**: `turn_complete` and `interrupted` can both be True in the same message. This indicates the turn ended due to an interruption.

## Interruption Handling

Interruptions are signaled via `server_content.interrupted`. There are two cases:

### Case 1: Interrupted with turn_complete

Both flags are True. The turn ends, and the response includes both signals:

```python
yield LlmResponse(turn_complete=True, interrupted=True)
break  # Loop exits
```

### Case 2: Interrupted without turn_complete

Only `interrupted` is True. The model was interrupted but the turn hasn't ended:

```python
if message.server_content.interrupted:
    if text:
        yield build_full_text_response(text)
        text = ''
    else:
        yield LlmResponse(interrupted=True)
    # Loop continues - no break
```

This can occur when the model might continue after the interruption is handled.

## Transcription Handling

### Accumulation Pattern

Transcriptions are accumulated across multiple messages and emitted with a `finished` flag:

```python
# Instance variables for accumulation.
self._input_transcription_text: str = ''
self._output_transcription_text: str = ''

# In receive():
if message.server_content.input_transcription:
    if message.server_content.input_transcription.text:
        # Accumulate partial text.
        self._input_transcription_text += (
            message.server_content.input_transcription.text
        )
        yield LlmResponse(
            input_transcription=types.Transcription(
                text=message.server_content.input_transcription.text,
                finished=False,
            ),
            partial=True,
        )

    # finished=True and partial text may arrive in the same message.
    if message.server_content.input_transcription.finished:
        yield LlmResponse(
            input_transcription=types.Transcription(
                text=self._input_transcription_text,  # Full accumulated text
                finished=True,
            ),
            partial=False,
        )
        self._input_transcription_text = ''  # Reset accumulator
```

### Fallback Flush (GEMINI_API Only)

The Gemini API may not always send a `finished=True` signal. For this backend, adk-python implements a fallback flush on control events:

```python
# Only for GEMINI_API backend.
if self._api_backend == GoogleLLMVariant.GEMINI_API and (
    message.server_content.interrupted
    or message.server_content.turn_complete
    or message.server_content.generation_complete
):
    if self._input_transcription_text:
        yield LlmResponse(
            input_transcription=types.Transcription(
                text=self._input_transcription_text,
                finished=True,
            ),
            partial=False,
        )
        self._input_transcription_text = ''

    if self._output_transcription_text:
        yield LlmResponse(
            output_transcription=types.Transcription(
                text=self._output_transcription_text,
                finished=True,
            ),
            partial=False,
        )
        self._output_transcription_text = ''
```

**Note**: This fallback is specifically for the GEMINI_API backend. Other backends may reliably send `finished=True`.

## Sending Content

### send_history()

Sends conversation history when establishing a connection or transferring between agents.

```python
async def send_history(self, history: list[types.Content]):
    # CRITICAL: Filter out audio parts.
    # 1. Audio has already been transcribed.
    # 2. Sending audio via send() corrupts the session.
    contents = [
        filtered
        for content in history
        if (filtered := filter_audio_parts(content)) is not None
    ]

    if contents:
        await self._gemini_session.send(
            input=types.LiveClientContent(
                turns=contents,
                # Only set turn_complete=True if last message is from user.
                # This controls whether model responds immediately.
                turn_complete=contents[-1].role == 'user',
            ),
        )
```

**Key insight**: Setting `turn_complete` based on the last message's role controls inference:
- Last message from user → `turn_complete=True` → model responds immediately
- Last message from model → `turn_complete=False` → model waits for user input

### send_content()

Sends user content or function responses during a session.

```python
async def send_content(self, content: types.Content):
    assert content.parts

    if content.parts[0].function_response:
        # Function responses use LiveClientToolResponse.
        function_responses = [part.function_response for part in content.parts]
        await self._gemini_session.send(
            input=types.LiveClientToolResponse(
                function_responses=function_responses
            ),
        )
    else:
        # Regular content uses LiveClientContent.
        await self._gemini_session.send(
            input=types.LiveClientContent(
                turns=[content],
                turn_complete=True,
            )
        )
```

**Important**: All parts must be function responses if the first part is a function response.

### send_realtime()

Sends audio blobs or activity signals for real-time input.

```python
RealtimeInput = Union[types.Blob, types.ActivityStart, types.ActivityEnd]

async def send_realtime(self, input: RealtimeInput):
    if isinstance(input, types.Blob):
        await self._gemini_session.send_realtime_input(media=input)

    elif isinstance(input, types.ActivityStart):
        await self._gemini_session.send_realtime_input(activity_start=input)

    elif isinstance(input, types.ActivityEnd):
        await self._gemini_session.send_realtime_input(activity_end=input)

    else:
        raise ValueError(f'Unsupported input type: {type(input)}')
```

## Tool Call Handling

Tool calls arrive via `message.tool_call` and contain function call requests.

```python
if message.tool_call:
    # Flush any accumulated text first.
    if text:
        yield self.__build_full_text_response(text)
        text = ''

    # Convert function calls to Content parts.
    parts = [
        types.Part(function_call=function_call)
        for function_call in message.tool_call.function_calls
    ]
    yield LlmResponse(content=types.Content(role='model', parts=parts))
```

**Note from source**: Tool calls may arrive before `generation_complete`, causing transcription to appear after tool_call in the session log.

## Session Resumption

Session resumption updates are yielded directly:

```python
if message.session_resumption_update:
    yield LlmResponse(
        live_session_resumption_update=message.session_resumption_update
    )
```

Store the handle for reconnection:

```python
if response.live_session_resumption_update:
    self._resumption_handle = response.live_session_resumption_update.handle
```

## Complete Event Flow Examples

### Text Response Turn

```
1. User sends: "What is 2+2?"

2. Receive loop yields:
   ├─ usage_metadata (token counts)
   ├─ LlmResponse(content="The", partial=True)
   ├─ LlmResponse(content=" answer", partial=True)
   ├─ LlmResponse(content=" is", partial=True)
   ├─ LlmResponse(content=" 4.", partial=True)
   ├─ LlmResponse(content="The answer is 4.", partial=False)  # Merged text
   └─ LlmResponse(turn_complete=True)
   [loop breaks]

3. Call receive() again for next turn.
```

### Audio Response Turn

```
1. User speaks (audio sent via send_realtime)

2. Receive loop yields:
   ├─ input_transcription: "What" (partial=True)
   ├─ input_transcription: " time" (partial=True)
   ├─ input_transcription: " is it?" (partial=True)
   ├─ input_transcription: "What time is it?" (finished=True)
   ├─ output_transcription: "It's 3pm" (partial=True)
   ├─ LlmResponse(content=audio_chunk_1)
   ├─ LlmResponse(content=audio_chunk_2)
   ├─ output_transcription: "It's 3pm." (finished=True)
   └─ LlmResponse(turn_complete=True)
   [loop breaks]
```

### Interrupted Turn

```
1. Model responding with audio

2. User interrupts (barge-in detected)

3. Receive loop yields:
   ├─ LlmResponse(content=audio_chunk_1)
   ├─ LlmResponse(content=audio_chunk_2)
   └─ LlmResponse(turn_complete=True, interrupted=True)
   [loop breaks]

4. New turn begins with user's interruption.
```

### Function Call Turn

```
1. User: "What's the weather?"

2. Receive loop yields:
   ├─ usage_metadata
   ├─ LlmResponse(content=FunctionCall(name="get_weather", args={...}))
   [loop continues - no turn_complete yet]

3. Client executes function, sends response via send_content()

4. Receive loop continues:
   ├─ LlmResponse(content="The weather is sunny.")
   └─ LlmResponse(turn_complete=True)
   [loop breaks]
```

## State Management

Track these states in your implementation:

```python
class ConnectionState:
    def __init__(self):
        # Text accumulation.
        self._accumulated_text = ''

        # Transcription accumulation.
        self._input_transcription_text = ''
        self._output_transcription_text = ''

        # Session state.
        self._resumption_handle: str | None = None

        # Response tracking (for UI/audio playback).
        self._bot_is_responding = False
```

## Audio Filtering for History

When sending conversation history, audio parts must be filtered out:

```python
def filter_audio_parts(content: types.Content) -> types.Content | None:
    """Filter audio parts from content before sending to Live API."""
    if not content or not content.parts:
        return None

    filtered_parts = [
        part for part in content.parts
        if not (part.inline_data and
                part.inline_data.mime_type.startswith("audio/"))
    ]

    if not filtered_parts:
        return None

    return types.Content(role=content.role, parts=filtered_parts)
```

**Why this matters**:
1. Audio has already been transcribed - the transcription is in the context
2. Sending audio via `send()` (not `send_realtime_input()`) corrupts the session
