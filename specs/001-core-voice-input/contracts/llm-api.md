# Contract: LLM Polishing API

**Endpoint**: `POST {llm.base_url}/chat/completions`
**Auth**: `Authorization: Bearer {llm.api_key}`

## Request

Content-Type: `application/json`

```json
{
  "model": "gpt-4o-mini",
  "messages": [
    {
      "role": "system",
      "content": "Polish the following transcript for grammar and punctuation. Preserve the original language. Do not add explanations."
    },
    {
      "role": "user",
      "content": "{raw_transcription}"
    }
  ],
  "temperature": 0.0,
  "max_tokens": 4096
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `model` | string | Yes | `{llm.model}` from config |
| `messages` | array | Yes | System + user messages |
| `temperature` | number | No | `{llm.temperature}` from config |
| `max_tokens` | integer | No | `{llm.max_tokens}` from config |

## Response (JSON)

```json
{
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "润色后的文本"
      }
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `choices[0].message.content` | string | The polished text to inject |

## Error Responses

Standard HTTP status codes with a JSON body containing an `error` object.

## Client Obligations

- Timeout after 10 seconds.
- On any non-2xx response, timeout, or empty `choices`, fall back to injecting the raw ASR transcription (FR-013).
- Strip leading/trailing whitespace from the returned content before injection.
