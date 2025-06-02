package main

import (
	"encoding/json"
	"testing"
	"time"
)

func TestCLIOutput_Success(t *testing.T) {
	data := map[string]interface{}{
		"test": "value",
		"num":  42,
	}
	
	output := CLIOutput{
		Success: true,
		Data:    data,
	}
	
	jsonBytes, err := json.Marshal(output)
	if err != nil {
		t.Fatalf("Failed to marshal output: %v", err)
	}
	
	var parsed CLIOutput
	err = json.Unmarshal(jsonBytes, &parsed)
	if err != nil {
		t.Fatalf("Failed to unmarshal output: %v", err)
	}
	
	if !parsed.Success {
		t.Error("Expected success to be true")
	}
	
	if parsed.Error != "" {
		t.Error("Expected error to be empty for success case")
	}
	
	if parsed.Data == nil {
		t.Error("Expected data to be present")
	}
}

func TestCLIOutput_Error(t *testing.T) {
	output := CLIOutput{
		Success: false,
		Error:   "test error message",
	}
	
	jsonBytes, err := json.Marshal(output)
	if err != nil {
		t.Fatalf("Failed to marshal output: %v", err)
	}
	
	var parsed CLIOutput
	err = json.Unmarshal(jsonBytes, &parsed)
	if err != nil {
		t.Fatalf("Failed to unmarshal output: %v", err)
	}
	
	if parsed.Success {
		t.Error("Expected success to be false")
	}
	
	if parsed.Error != "test error message" {
		t.Errorf("Expected error message 'test error message', got '%s'", parsed.Error)
	}
	
	if parsed.Data != nil {
		t.Error("Expected data to be nil for error case")
	}
}

func TestParseEmailAddresses(t *testing.T) {
	testData := []interface{}{
		map[string]interface{}{
			"name":  "John Doe",
			"email": "john@example.com",
		},
		map[string]interface{}{
			"email": "jane@example.com",
		},
	}
	
	result := parseEmailAddresses(testData)
	
	if len(result) != 2 {
		t.Fatalf("Expected 2 email addresses, got %d", len(result))
	}
	
	if result[0].Name != "John Doe" {
		t.Errorf("Expected name 'John Doe', got '%s'", result[0].Name)
	}
	
	if result[0].Email != "john@example.com" {
		t.Errorf("Expected email 'john@example.com', got '%s'", result[0].Email)
	}
	
	if result[1].Name != "" {
		t.Errorf("Expected empty name for second address, got '%s'", result[1].Name)
	}
	
	if result[1].Email != "jane@example.com" {
		t.Errorf("Expected email 'jane@example.com', got '%s'", result[1].Email)
	}
}

func TestGetString(t *testing.T) {
	testMap := map[string]interface{}{
		"existing":    "value",
		"nil_value":   nil,
		"empty_string": "",
		"number":      42,
	}
	
	if getString(testMap, "existing") != "value" {
		t.Error("Failed to get existing string value")
	}
	
	if getString(testMap, "nil_value") != "" {
		t.Error("Expected empty string for nil value")
	}
	
	if getString(testMap, "empty_string") != "" {
		t.Error("Expected empty string for empty string value")
	}
	
	if getString(testMap, "nonexistent") != "" {
		t.Error("Expected empty string for nonexistent key")
	}
}

func TestEmailStructSerialization(t *testing.T) {
	email := Email{
		ID:       "test-id",
		ThreadID: "test-thread",
		Subject:  "Test Subject",
		Preview:  "Test preview",
		Size:     1024,
		ReceivedAt: time.Date(2024, 1, 15, 10, 30, 0, 0, time.UTC),
		From: []EmailAddress{
			{Name: "Sender", Email: "sender@example.com"},
		},
		To: []EmailAddress{
			{Name: "Recipient", Email: "recipient@example.com"},
		},
		HasAttachment: true,
		Keywords: map[string]bool{
			"$seen": true,
			"$flagged": false,
		},
	}
	
	jsonBytes, err := json.Marshal(email)
	if err != nil {
		t.Fatalf("Failed to marshal email: %v", err)
	}
	
	var parsed Email
	err = json.Unmarshal(jsonBytes, &parsed)
	if err != nil {
		t.Fatalf("Failed to unmarshal email: %v", err)
	}
	
	if parsed.ID != email.ID {
		t.Errorf("ID mismatch: expected %s, got %s", email.ID, parsed.ID)
	}
	
	if parsed.Subject != email.Subject {
		t.Errorf("Subject mismatch: expected %s, got %s", email.Subject, parsed.Subject)
	}
	
	if !parsed.ReceivedAt.Equal(email.ReceivedAt) {
		t.Errorf("ReceivedAt mismatch: expected %v, got %v", email.ReceivedAt, parsed.ReceivedAt)
	}
	
	if len(parsed.From) != 1 || parsed.From[0].Email != "sender@example.com" {
		t.Error("From address parsing failed")
	}
	
	if len(parsed.To) != 1 || parsed.To[0].Email != "recipient@example.com" {
		t.Error("To address parsing failed")
	}
	
	if !parsed.HasAttachment {
		t.Error("HasAttachment should be true")
	}
	
	if !parsed.Keywords["$seen"] {
		t.Error("$seen keyword should be true")
	}
}

func TestMailboxStructSerialization(t *testing.T) {
	mailbox := Mailbox{
		ID:           "mailbox-123",
		Name:         "INBOX",
		ParentID:     "",
		Role:         "inbox",
		TotalEmails:  100,
		UnreadEmails: 5,
	}
	
	jsonBytes, err := json.Marshal(mailbox)
	if err != nil {
		t.Fatalf("Failed to marshal mailbox: %v", err)
	}
	
	var parsed Mailbox
	err = json.Unmarshal(jsonBytes, &parsed)
	if err != nil {
		t.Fatalf("Failed to unmarshal mailbox: %v", err)
	}
	
	if parsed.ID != mailbox.ID {
		t.Errorf("ID mismatch: expected %s, got %s", mailbox.ID, parsed.ID)
	}
	
	if parsed.Name != mailbox.Name {
		t.Errorf("Name mismatch: expected %s, got %s", mailbox.Name, parsed.Name)
	}
	
	if parsed.Role != mailbox.Role {
		t.Errorf("Role mismatch: expected %s, got %s", mailbox.Role, parsed.Role)
	}
	
	if parsed.TotalEmails != mailbox.TotalEmails {
		t.Errorf("TotalEmails mismatch: expected %d, got %d", mailbox.TotalEmails, parsed.TotalEmails)
	}
	
	if parsed.UnreadEmails != mailbox.UnreadEmails {
		t.Errorf("UnreadEmails mismatch: expected %d, got %d", mailbox.UnreadEmails, parsed.UnreadEmails)
	}
}

func TestJMAPRequestStructure(t *testing.T) {
	request := JMAPRequest{
		Using: []string{"urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"},
		MethodCalls: []interface{}{
			[]interface{}{
				"Mailbox/get",
				map[string]interface{}{
					"accountId": "account-123",
				},
				"0",
			},
		},
	}
	
	jsonBytes, err := json.Marshal(request)
	if err != nil {
		t.Fatalf("Failed to marshal JMAP request: %v", err)
	}
	
	var parsed JMAPRequest
	err = json.Unmarshal(jsonBytes, &parsed)
	if err != nil {
		t.Fatalf("Failed to unmarshal JMAP request: %v", err)
	}
	
	if len(parsed.Using) != 2 {
		t.Errorf("Expected 2 using capabilities, got %d", len(parsed.Using))
	}
	
	if parsed.Using[0] != "urn:ietf:params:jmap:core" {
		t.Errorf("Expected first capability to be jmap:core, got %s", parsed.Using[0])
	}
	
	if len(parsed.MethodCalls) != 1 {
		t.Errorf("Expected 1 method call, got %d", len(parsed.MethodCalls))
	}
}

func TestGetAccountID(t *testing.T) {
	// Test with nil session
	session = nil
	accountID := getAccountID()
	if accountID != "" {
		t.Error("Expected empty account ID when session is nil")
	}
	
	// Test with session containing primary accounts
	session = &JMAPSession{
		PrimaryAccounts: map[string]string{
			"urn:ietf:params:jmap:mail": "account-123",
		},
	}
	
	accountID = getAccountID()
	if accountID != "account-123" {
		t.Errorf("Expected account ID 'account-123', got '%s'", accountID)
	}
	
	// Clean up
	session = nil
}