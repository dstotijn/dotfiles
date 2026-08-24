# Rate Limits & Constraints

Understanding the rate limits and constraints of the Gemini Live API is essential for building production applications.

## Rate Limits

| Resource | Limit |
|----------|-------|
| Concurrent Sessions | 5,000 per project |
| Token Rate | 4M tokens per minute |
| Audio Session Limit | 15 minutes |
| Audio + Video Session Limit | 2 minutes |

## Context Windows

| Model Type | Context Window |
|------------|---------------|
| Native Audio Models | 128k tokens |
| Standard Models | 32k tokens |

## Audio Constraints

| Specification | Constraint |
|---------------|------------|
| Input Sample Rate | 16 kHz (native), any rate accepted |
| Output Sample Rate | 24 kHz |
| Input Format | 16-bit PCM, mono |
| Video Frame Rate | 1 FPS (processed) |

## Token Counting

Tokens are counted differently for each modality:

| Modality | Approximate Token Rate |
|----------|----------------------|
| Text | ~4 characters per token |
| Audio Input | ~25 tokens per second |
| Audio Output | ~50 tokens per second |
| Video | ~258 tokens per frame (1 FPS) |

Use `usageMetadata` in responses to track actual token consumption:

```json
{
  "usageMetadata": {
    "promptTokenCount": 1500,
    "responseTokenCount": 250,
    "totalTokenCount": 1750,
    "promptTokensDetails": [
      { "modality": "AUDIO", "tokenCount": 1200 },
      { "modality": "TEXT", "tokenCount": 300 }
    ]
  }
}
```

## Known Limitations

### Unsupported Features

| Feature | Status |
|---------|--------|
| Token count prediction | Not supported |
| Manual endpointing | Not supported |
| Response logprobs | Not supported |
| Response schema enforcement | Not supported |
| Stop sequences | Not supported |
| Audio timestamps | Not supported |

### Audio Impact on Function Calling

Function calling reliability is reduced when using audio input/output compared to text-only interactions. For critical function calls, consider:

1. Using text-only mode for function-heavy workflows.
2. Implementing retry logic for function calls.
3. Validating function results before acting.

### Video Limitations

- Video is processed at 1 FPS.
- Fast-motion video analysis (sports, action) is not suitable.
- High-speed events may be missed between frames.

### Session Resumption Constraints

Session resumption is unavailable when:

- Active function execution is in progress.
- Model is currently generating a response.
- The session has expired.
- The resumption handle has been invalidated.

## Ephemeral Token Constraints

For client-side authentication:

| Parameter | Default | Maximum |
|-----------|---------|---------|
| Token Expiration | 30 minutes | 20 hours |
| New Session Expiration | 60 seconds | - |
| Uses | Unlimited within expiration | Configurable |

```json
{
  "authToken": {
    "expireTime": "2024-01-01T12:30:00Z",
    "newSessionExpireTime": "2024-01-01T12:01:00Z",
    "uses": 5
  }
}
```

## Handling Rate Limits

### Concurrent Session Management

```python
import asyncio
from collections import defaultdict

class SessionPool:
    def __init__(self, max_sessions=100):
        self.max_sessions = max_sessions
        self.active_sessions = 0
        self.waiting = asyncio.Queue()
        self.lock = asyncio.Lock()

    async def acquire(self):
        async with self.lock:
            if self.active_sessions < self.max_sessions:
                self.active_sessions += 1
                return True

        # Wait for a session to become available
        await self.waiting.get()
        return await self.acquire()

    async def release(self):
        async with self.lock:
            self.active_sessions -= 1
            try:
                self.waiting.put_nowait(True)
            except asyncio.QueueFull:
                pass
```

### Token Rate Limiting

```python
import time
from collections import deque

class TokenRateLimiter:
    def __init__(self, max_tokens_per_minute=4_000_000):
        self.max_tokens = max_tokens_per_minute
        self.window = 60  # seconds
        self.usage = deque()

    def record_usage(self, tokens: int):
        now = time.time()
        self.usage.append((now, tokens))
        self._cleanup()

    def _cleanup(self):
        now = time.time()
        while self.usage and now - self.usage[0][0] > self.window:
            self.usage.popleft()

    def can_proceed(self, estimated_tokens: int) -> bool:
        self._cleanup()
        current_usage = sum(tokens for _, tokens in self.usage)
        return current_usage + estimated_tokens <= self.max_tokens

    def wait_time(self) -> float:
        if not self.usage:
            return 0
        oldest = self.usage[0][0]
        return max(0, self.window - (time.time() - oldest))
```

### Session Duration Management

```python
import asyncio
from datetime import datetime, timedelta

class SessionManager:
    def __init__(self, max_duration_minutes=14):
        self.max_duration = timedelta(minutes=max_duration_minutes)
        self.start_time = None
        self.resumption_handle = None

    async def start_session(self, session):
        self.start_time = datetime.now()

        # Schedule session refresh before timeout
        refresh_time = self.max_duration.total_seconds() - 60
        asyncio.create_task(self._schedule_refresh(session, refresh_time))

    async def _schedule_refresh(self, session, delay):
        await asyncio.sleep(delay)

        if self.resumption_handle:
            print("Session approaching limit, preparing to refresh...")
            # The actual refresh happens when we receive GoAway

    def update_handle(self, handle):
        self.resumption_handle = handle

    def time_remaining(self) -> timedelta:
        if not self.start_time:
            return self.max_duration
        elapsed = datetime.now() - self.start_time
        return max(timedelta(0), self.max_duration - elapsed)
```

## Best Practices

### 1. Monitor Usage

Track token consumption to avoid hitting limits:

```python
class UsageTracker:
    def __init__(self):
        self.total_input_tokens = 0
        self.total_output_tokens = 0
        self.session_count = 0

    def record(self, usage_metadata):
        self.total_input_tokens += usage_metadata.get('promptTokenCount', 0)
        self.total_output_tokens += usage_metadata.get('responseTokenCount', 0)

    def report(self):
        return {
            'total_input_tokens': self.total_input_tokens,
            'total_output_tokens': self.total_output_tokens,
            'total_tokens': self.total_input_tokens + self.total_output_tokens,
            'sessions': self.session_count,
        }
```

### 2. Implement Backoff

Handle rate limit errors with exponential backoff:

```python
import asyncio
import random

async def with_backoff(func, max_retries=5):
    for attempt in range(max_retries):
        try:
            return await func()
        except RateLimitError:
            if attempt == max_retries - 1:
                raise

            delay = (2 ** attempt) + random.uniform(0, 1)
            print(f"Rate limited, waiting {delay:.2f}s...")
            await asyncio.sleep(delay)
```

### 3. Use Context Compression

Configure automatic context compression to stay within limits:

```json
{
  "contextWindowCompression": {
    "slidingWindow": {
      "targetTokens": 80000
    },
    "triggerTokens": 100000
  }
}
```

### 4. Batch Operations

When possible, batch multiple operations into single sessions:

```python
async def batch_process(items, session):
    results = []
    for item in items:
        result = await process_item(session, item)
        results.append(result)

        # Check if we're approaching limits
        if session.token_count > 100000:
            # Save state and create new session
            break

    return results
```

### 5. Graceful Degradation

Handle limit exhaustion gracefully:

```python
class GracefulService:
    def __init__(self):
        self.rate_limiter = TokenRateLimiter()

    async def process(self, request):
        if not self.rate_limiter.can_proceed(estimated_tokens=1000):
            wait = self.rate_limiter.wait_time()
            if wait > 30:  # More than 30 seconds
                return self.fallback_response(request)
            await asyncio.sleep(wait)

        return await self.live_api_process(request)

    def fallback_response(self, request):
        return {
            "status": "rate_limited",
            "message": "Service temporarily at capacity. Please try again shortly.",
            "retry_after": 60
        }
```

## Error Responses

Common rate limit error responses:

| Error Code | Description | Action |
|------------|-------------|--------|
| 429 | Too Many Requests | Implement backoff and retry |
| 503 | Service Unavailable | Wait and retry with backoff |
| RESOURCE_EXHAUSTED | Quota exceeded | Check quota, wait, or upgrade |

```json
{
  "error": {
    "code": 429,
    "message": "Rate limit exceeded",
    "status": "RESOURCE_EXHAUSTED",
    "details": [
      {
        "reason": "RATE_LIMIT_EXCEEDED",
        "metadata": {
          "quota_limit": "4000000",
          "quota_consumed": "4500000"
        }
      }
    ]
  }
}
```
