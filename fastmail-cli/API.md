# Fastmail CLI API Documentation

## Overview

The Fastmail CLI is a command-line interface that interacts with the Fastmail JMAP (JSON Meta Application Protocol) API. It provides structured JSON output suitable for consumption by scripts, tools, and AI assistants.

## Authentication

### API Token Setup

1. **Generate Token**: Go to Fastmail Settings → Privacy & Security → Integrations
2. **Create New API Token** with required scopes:
   - `urn:ietf:params:jmap:core` (required)
   - `urn:ietf:params:jmap:mail` (for email access)
3. **Authenticate CLI**: `fastmail-cli auth YOUR_TOKEN_HERE`

### Token Storage

- Tokens are stored in `~/.fastmail-cli/config.yaml`
- File permissions are set to 0600 (user read/write only)
- Config file is not tracked by git

## Commands

### Authentication

```bash
fastmail-cli auth <token>
```

**Response Format:**
```json
{
  "success": true,
  "data": {
    "message": "Authentication successful",
    "username": "user@fastmail.com",
    "accounts": 1
  }
}
```

### List Mailboxes

```bash
fastmail-cli list mailboxes
```

**Response Format:**
```json
{
  "success": true,
  "data": [
    {
      "id": "mailbox-id-123",
      "name": "INBOX",
      "parentId": "",
      "role": "inbox",
      "totalEmails": 1337,
      "unreadEmails": 42
    }
  ]
}
```

**Mailbox Object Properties:**
- `id`: Unique mailbox identifier
- `name`: Human-readable mailbox name
- `parentId`: Parent mailbox ID (for nested folders)
- `role`: Special mailbox role (inbox, sent, trash, etc.)
- `totalEmails`: Total number of emails
- `unreadEmails`: Number of unread emails

### List Emails

```bash
fastmail-cli list emails [--mailbox MAILBOX] [--limit COUNT]
```

**Parameters:**
- `--mailbox`: Mailbox name (default: "INBOX")
- `--limit`: Maximum emails to retrieve (default: 50)

**Response Format:**
```json
{
  "success": true,
  "data": [
    {
      "id": "email-id-456",
      "threadId": "thread-id-789",
      "subject": "Meeting Tomorrow",
      "preview": "Just a reminder about our meeting...",
      "from": [
        {
          "name": "John Doe",
          "email": "john@example.com"
        }
      ],
      "to": [
        {
          "name": "Jane Smith", 
          "email": "jane@fastmail.com"
        }
      ],
      "receivedAt": "2024-01-15T10:30:00Z",
      "size": 2048,
      "hasAttachment": false,
      "keywords": {
        "$seen": true,
        "$flagged": false
      }
    }
  ]
}
```

**Email Object Properties:**
- `id`: Unique email identifier
- `threadId`: Thread/conversation identifier
- `subject`: Email subject line
- `preview`: Text preview of email content
- `from`: Array of sender email addresses
- `to`: Array of recipient email addresses
- `cc`: Array of CC recipients (when available)
- `bcc`: Array of BCC recipients (when available)
- `receivedAt`: ISO 8601 timestamp
- `size`: Email size in bytes
- `hasAttachment`: Boolean indicating attachments
- `keywords`: JMAP keywords object (seen, flagged, etc.)

### Get Specific Email

```bash
fastmail-cli get email <email-id>
```

**Response Format:**
```json
{
  "success": true,
  "data": {
    "id": "email-id-456",
    "threadId": "thread-id-789",
    "subject": "Meeting Tomorrow",
    "preview": "Just a reminder about our meeting...",
    "from": [...],
    "to": [...],
    "cc": [...],
    "bcc": [...],
    "receivedAt": "2024-01-15T10:30:00Z",
    "size": 2048,
    "hasAttachment": false,
    "keywords": {...},
    "headers": {
      "message-id": "<msg123@example.com>",
      "user-agent": "Mail Client 1.0"
    },
    "textBody": [...],
    "htmlBody": [...]
  }
}
```

**Additional Properties for Full Email:**
- `headers`: Email headers as key-value pairs
- `textBody`: Array of text body parts
- `htmlBody`: Array of HTML body parts

### Search Emails

```bash
fastmail-cli search "<query>"
```

**Query Examples:**
- `"from:example@domain.com"`
- `"subject:meeting"`
- `"urgent"`
- `"has:attachment"`
- `"before:2024-01-01"`

**Response Format:**
```json
{
  "success": true,
  "data": {
    "query": "from:example@domain.com",
    "results": 5,
    "emails": [...]
  }
}
```

## Error Handling

### Error Response Format

```json
{
  "success": false,
  "error": "Error description here"
}
```

### Common Errors

| Error | Description | Solution |
|-------|-------------|----------|
| `not authenticated` | No API token configured | Run `fastmail-cli auth <token>` |
| `HTTP 401` | Invalid or expired token | Generate new token and re-authenticate |
| `HTTP 429` | Rate limit exceeded | Wait before retrying |
| `mailbox 'X' not found` | Invalid mailbox name | Use `list mailboxes` to see available ones |
| `email not found` | Invalid email ID | Verify email ID exists |

## JMAP Protocol Details

### Session Endpoint
- **URL**: `https://api.fastmail.com/jmap/session`
- **Method**: GET
- **Auth**: Bearer token

### API Endpoint
- **URL**: Provided in session response (`apiUrl`)
- **Method**: POST
- **Content-Type**: `application/json`
- **Auth**: Bearer token

### Request Structure
```json
{
  "using": [
    "urn:ietf:params:jmap:core",
    "urn:ietf:params:jmap:mail"
  ],
  "methodCalls": [
    ["Method/name", {parameters}, "request-id"]
  ]
}
```

### Response Structure
```json
{
  "methodResponses": [
    ["Method/response", {data}, "request-id"]
  ],
  "sessionState": "session-state-string"
}
```

## Rate Limits

- Fastmail implements rate limiting on API requests
- CLI automatically respects HTTP 429 responses
- Recommended: Add delays between batch operations

## Security Considerations

1. **Token Security**:
   - Store tokens securely (CLI uses 0600 permissions)
   - Use read-only tokens when possible
   - Rotate tokens regularly

2. **Network Security**:
   - All requests use HTTPS
   - Validate SSL certificates
   - Consider using VPN for sensitive operations

3. **Data Handling**:
   - JSON output may contain sensitive email content
   - Be careful with logging and error handling
   - Clear sensitive data from memory when possible

## Capabilities and Scopes

### Core Capabilities
- `urn:ietf:params:jmap:core`: Basic JMAP functionality
- `urn:ietf:params:jmap:mail`: Email access and management
- `urn:ietf:params:jmap:submission`: Email sending
- `https://www.fastmail.com/dev/maskedemail`: Masked email management

### Data Types
- **Mailbox**: Email folders/labels
- **Email**: Email messages
- **Thread**: Email conversations
- **EmailSubmission**: Outgoing emails
- **Identity**: Sending identities
- **MaskedEmail**: Generated alias addresses

## Integration Examples

### Shell Scripting with jq
```bash
# Get unread count
fastmail-cli list mailboxes | jq '.data[] | select(.name=="INBOX") | .unreadEmails'

# Extract sender emails
fastmail-cli list emails | jq -r '.data[].from[].email'

# Find emails with attachments
fastmail-cli list emails | jq '.data[] | select(.hasAttachment==true)'
```

### Python Integration
```python
import json
import subprocess

def get_unread_emails():
    result = subprocess.run(['fastmail-cli', 'list', 'emails'], 
                          capture_output=True, text=True)
    data = json.loads(result.stdout)
    if data['success']:
        return [email for email in data['data'] 
                if not email['keywords'].get('$seen', False)]
    return []
```

### Node.js Integration
```javascript
const { execSync } = require('child_process');

function searchEmails(query) {
  try {
    const output = execSync(`fastmail-cli search "${query}"`, 
                           { encoding: 'utf8' });
    return JSON.parse(output);
  } catch (error) {
    return { success: false, error: error.message };
  }
}
```

## Extending the CLI

The CLI is designed for extensibility:

1. **Add new commands** by extending the Cobra command structure
2. **Add new data types** by implementing JMAP method calls
3. **Customize output formats** by modifying the `CLIOutput` structure
4. **Add filtering/sorting** by extending command flags

For development, see the source code and test files for implementation patterns.