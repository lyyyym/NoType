# Contract: ASR API

**Endpoint**: `POST {asr.base_url}/audio/transcriptions`
**Auth**: `Authorization: Bearer {asr.api_key}`

## Request

Content-Type: `multipart/form-data`

| Part | Type | Required | Description |
|------|------|----------|-------------|
| `file` | binary | Yes | WAV audio file, 16-bit PCM, 16 kHz, mono |
| `model` | string | Yes | `{asr.model}` from config |
| `language` | string | No | Hint for the spoken language; omitted to enable auto-detection |
| `response_format` | string | No | `"json"` or `"text"`; default `"json"` |

## Response (JSON)

```json
{
  "text": "原始识别文本"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `text` | string | The raw transcript of the audio |

## Error Responses

Standard HTTP status codes with a JSON body containing an `error` object:

```json
{
  "error": {
    "message": "...",
    "type": "...",
    "code": "..."
  }
}
```

## Client Obligations

- Send a valid WAV file with correct header.
- Timeout after 30 seconds.
- On any non-2xx response or timeout, surface the error to the recording session and do not proceed to LLM polishing.
