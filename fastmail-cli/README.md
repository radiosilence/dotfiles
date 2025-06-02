# Fastmail CLI

A command-line interface for querying the Fastmail JMAP API to list and retrieve emails. Outputs structured JSON data that can be easily parsed by other tools and AI assistants.

## Setup

### 1. Get a Fastmail API Token

1. Log into your Fastmail account
2. Go to Settings → Privacy & Security → Integrations
3. Click "New API token"
4. Give it a name (e.g. "CLI Tool")
5. Select the scopes you need:
   - `urn:ietf:params:jmap:core` (required)
   - `urn:ietf:params:jmap:mail` (for email access)
6. Copy the generated token

### 2. Build and Install

```bash
cd .dotfiles/fastmail-cli
task setup
```

Install to system PATH:
```bash
task install
```

Or install to ~/bin (make sure ~/bin is in your PATH):
```bash
task install-local
```

### 3. Authenticate

```bash
./fastmail-cli auth YOUR_API_TOKEN_HERE
```

The token will be stored securely in `~/.fastmail-cli/config.yaml` (not in git).

## Usage

### List Mailboxes
```bash
./fastmail-cli list mailboxes
```

### List Emails
```bash
# List emails from INBOX (default)
./fastmail-cli list emails

# List emails from a specific mailbox
./fastmail-cli list emails --mailbox "Sent"

# Limit number of emails
./fastmail-cli list emails --limit 10
```

### Get Specific Email
```bash
./fastmail-cli get email EMAIL_ID_HERE
```

### Search Emails
```bash
./fastmail-cli search "from:example@domain.com"
./fastmail-cli search "subject:meeting"
./fastmail-cli search "urgent"
```

## Output Format

All commands output structured JSON in the following format:

```json
{
  "success": true,
  "data": { ... },
  "error": "",
  "message": ""
}
```

Success responses include the requested data in the `data` field.
Error responses have `success: false` and details in the `error` field.

## Example Outputs

### List Mailboxes
```json
{
  "success": true,
  "data": [
    {
      "id": "mailbox-id-123",
      "name": "INBOX",
      "role": "inbox",
      "totalEmails": 42,
      "unreadEmails": 5
    }
  ]
}
```

### List Emails
```json
{
  "success": true,
  "data": [
    {
      "id": "email-id-456",
      "threadId": "thread-id-789",
      "subject": "Meeting Tomorrow",
      "preview": "Just a reminder about our meeting...",
      "from": [{"name": "John Doe", "email": "john@example.com"}],
      "to": [{"name": "You", "email": "you@fastmail.com"}],
      "receivedAt": "2024-01-15T10:30:00Z",
      "size": 1024,
      "hasAttachment": false,
      "keywords": {"$seen": true}
    }
  ]
}
```

## Dependencies

- Go 1.21+
- github.com/spf13/cobra (CLI framework)
- github.com/spf13/viper (configuration management)

## Security

- API tokens are stored locally in `~/.fastmail-cli/config.yaml`
- This file is not tracked by git
- Tokens are sent over HTTPS only
- Consider using read-only tokens if you don't need write access

## JMAP Capabilities

This tool uses the Fastmail JMAP API which supports:
- urn:ietf:params:jmap:core
- urn:ietf:params:jmap:mail
- urn:ietf:params:jmap:submission
- https://www.fastmail.com/dev/maskedemail

For more information, see: https://www.fastmail.com/dev/