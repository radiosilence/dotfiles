package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

const (
	sessionURL = "https://api.fastmail.com/jmap/session"
	configDir  = ".fastmail-cli"
	configFile = "config"
)

type JMAPSession struct {
	Capabilities map[string]interface{} `json:"capabilities"`
	Accounts     map[string]Account     `json:"accounts"`
	PrimaryAccounts map[string]string   `json:"primaryAccounts"`
	Username     string                 `json:"username"`
	APIURL       string                 `json:"apiUrl"`
	DownloadURL  string                 `json:"downloadUrl"`
	UploadURL    string                 `json:"uploadUrl"`
	EventSourceURL string              `json:"eventSourceUrl"`
	State        string                 `json:"state"`
}

type Account struct {
	Name                 string `json:"name"`
	IsPersonal          bool   `json:"isPersonal"`
	IsReadOnly          bool   `json:"isReadOnly"`
	AccountCapabilities map[string]interface{} `json:"accountCapabilities"`
}

type JMAPRequest struct {
	Using       []string      `json:"using"`
	MethodCalls []interface{} `json:"methodCalls"`
}

type JMAPResponse struct {
	MethodResponses []interface{} `json:"methodResponses"`
	SessionState    string        `json:"sessionState"`
}

type Mailbox struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	ParentID    string `json:"parentId,omitempty"`
	Role        string `json:"role,omitempty"`
	TotalEmails int    `json:"totalEmails"`
	UnreadEmails int   `json:"unreadEmails"`
}

type Email struct {
	ID          string            `json:"id"`
	MessageID   []string          `json:"messageId"`
	ThreadID    string            `json:"threadId"`
	MailboxIDs  map[string]bool   `json:"mailboxIds"`
	Keywords    map[string]bool   `json:"keywords"`
	Size        int               `json:"size"`
	ReceivedAt  time.Time         `json:"receivedAt"`
	From        []EmailAddress    `json:"from"`
	To          []EmailAddress    `json:"to"`
	CC          []EmailAddress    `json:"cc,omitempty"`
	BCC         []EmailAddress    `json:"bcc,omitempty"`
	Subject     string            `json:"subject"`
	Preview     string            `json:"preview"`
	HasAttachment bool            `json:"hasAttachment"`
	Headers     map[string]string `json:"headers,omitempty"`
	TextBody    []EmailBodyPart   `json:"textBody,omitempty"`
	HTMLBody    []EmailBodyPart   `json:"htmlBody,omitempty"`
}

type EmailAddress struct {
	Name  string `json:"name,omitempty"`
	Email string `json:"email"`
}

type EmailBodyPart struct {
	PartID   string `json:"partId"`
	BlobID   string `json:"blobId"`
	Size     int    `json:"size"`
	Type     string `json:"type"`
	Charset  string `json:"charset,omitempty"`
}

type CLIOutput struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
	Message string      `json:"message,omitempty"`
}

type Identity struct {
	ID            string         `json:"id"`
	Name          string         `json:"name"`
	Email         string         `json:"email"`
	ReplyTo       []EmailAddress `json:"replyTo,omitempty"`
	BCC           []EmailAddress `json:"bcc,omitempty"`
	TextSignature string         `json:"textSignature,omitempty"`
	HTMLSignature string         `json:"htmlSignature,omitempty"`
}

type EmailSubmission struct {
	ID             string                 `json:"id,omitempty"`
	IdentityID     string                 `json:"identityId"`
	EmailID        string                 `json:"emailId"`
	ThreadID       string                 `json:"threadId,omitempty"`
	Envelope       *Envelope              `json:"envelope,omitempty"`
	SendAt         *time.Time             `json:"sendAt,omitempty"`
	UndoStatus     string                 `json:"undoStatus,omitempty"`
	DeliveryStatus map[string]interface{} `json:"deliveryStatus,omitempty"`
	DSNStatus      map[string]interface{} `json:"dsnStatus,omitempty"`
	MDNStatus      map[string]interface{} `json:"mdnStatus,omitempty"`
}

type Envelope struct {
	MailFrom EmailAddress   `json:"mailFrom"`
	RcptTo   []EmailAddress `json:"rcptTo"`
}

type EmailForSending struct {
	From        []EmailAddress    `json:"from"`
	To          []EmailAddress    `json:"to"`
	CC          []EmailAddress    `json:"cc,omitempty"`
	BCC         []EmailAddress    `json:"bcc,omitempty"`
	Subject     string            `json:"subject"`
	TextBody    []EmailBodyPart   `json:"textBody,omitempty"`
	HTMLBody    []EmailBodyPart   `json:"htmlBody,omitempty"`
	Attachments []EmailBodyPart   `json:"attachments,omitempty"`
	Keywords    map[string]bool   `json:"keywords,omitempty"`
	ReceivedAt  *time.Time        `json:"receivedAt,omitempty"`
	MessageID   []string          `json:"messageId,omitempty"`
	InReplyTo   []string          `json:"inReplyTo,omitempty"`
	References  []string          `json:"references,omitempty"`
}

var (
	apiToken string
	session  *JMAPSession
	client   = &http.Client{Timeout: 30 * time.Second}
)

func main() {
	if err := rootCmd.Execute(); err != nil {
		outputError(err.Error())
		os.Exit(1)
	}
}

var rootCmd = &cobra.Command{
	Use:   "fastmail-cli",
	Short: "CLI tool for Fastmail JMAP API",
	Long:  "A command-line interface for querying the Fastmail JMAP API to list and retrieve emails",
}

func init() {
	cobra.OnInitialize(initConfig)
	
	rootCmd.AddCommand(authCmd)
	rootCmd.AddCommand(listCmd)
	rootCmd.AddCommand(getCmd)
	rootCmd.AddCommand(searchCmd)
	rootCmd.AddCommand(sendCmd)
}

var authCmd = &cobra.Command{
	Use:   "auth [token]",
	Short: "Set up authentication with API token",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		token := args[0]
		
		// Test the token by getting session
		sess, err := getSession(token)
		if err != nil {
			outputError(fmt.Sprintf("Invalid token: %v", err))
			return
		}
		
		// Save token to config
		viper.Set("api_token", token)
		if err := viper.WriteConfig(); err != nil {
			outputError(fmt.Sprintf("Failed to save config: %v", err))
			return
		}
		
		outputSuccess(map[string]interface{}{
			"message":  "Authentication successful",
			"username": sess.Username,
			"accounts": len(sess.Accounts),
		})
	},
}

var listCmd = &cobra.Command{
	Use:   "list [mailboxes|emails]",
	Short: "List mailboxes or emails",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if err := ensureAuth(); err != nil {
			outputError(err.Error())
			return
		}
		
		switch args[0] {
		case "mailboxes":
			listMailboxes(cmd)
		case "emails":
			listEmails(cmd)
		default:
			outputError("Invalid list type. Use 'mailboxes' or 'emails'")
		}
	},
}

var getCmd = &cobra.Command{
	Use:   "get [email] [id]",
	Short: "Get specific email by ID",
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		if err := ensureAuth(); err != nil {
			outputError(err.Error())
			return
		}
		
		if args[0] != "email" {
			outputError("Currently only 'email' is supported")
			return
		}
		
		getEmail(args[1])
	},
}

var searchCmd = &cobra.Command{
	Use:   "search [query]",
	Short: "Search emails",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if err := ensureAuth(); err != nil {
			outputError(err.Error())
			return
		}
		
		searchEmails(args[0])
	},
}

var sendCmd = &cobra.Command{
	Use:   "send",
	Short: "Send an email",
	Run: func(cmd *cobra.Command, args []string) {
		if err := ensureAuth(); err != nil {
			outputError(err.Error())
			return
		}
		
		to, _ := cmd.Flags().GetString("to")
		subject, _ := cmd.Flags().GetString("subject")
		body, _ := cmd.Flags().GetString("body")
		cc, _ := cmd.Flags().GetString("cc")
		bcc, _ := cmd.Flags().GetString("bcc")
		
		if to == "" || subject == "" || body == "" {
			outputError("--to, --subject, and --body are required")
			return
		}
		
		sendEmail(to, subject, body, cc, bcc)
	},
}

func initConfig() {
	home, err := os.UserHomeDir()
	if err != nil {
		return
	}
	
	configPath := filepath.Join(home, configDir)
	viper.AddConfigPath(configPath)
	viper.SetConfigName(configFile)
	viper.SetConfigType("yaml")
	
	// Create config directory if it doesn't exist
	os.MkdirAll(configPath, 0700)
	
	// Read config file
	viper.ReadInConfig()
	
	apiToken = viper.GetString("api_token")
}

func ensureAuth() error {
	if apiToken == "" {
		return fmt.Errorf("not authenticated. Run 'fastmail-cli auth <token>' first")
	}
	
	if session == nil {
		sess, err := getSession(apiToken)
		if err != nil {
			return fmt.Errorf("authentication failed: %v", err)
		}
		session = sess
	}
	
	return nil
}

func getSession(token string) (*JMAPSession, error) {
	req, err := http.NewRequest("GET", sessionURL, nil)
	if err != nil {
		return nil, err
	}
	
	req.Header.Set("Authorization", "Bearer "+token)
	
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	
	var sess JMAPSession
	if err := json.NewDecoder(resp.Body).Decode(&sess); err != nil {
		return nil, err
	}
	
	return &sess, nil
}

func makeJMAPRequest(methodCalls []interface{}) (*JMAPResponse, error) {
	request := JMAPRequest{
		Using:       []string{"urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail", "urn:ietf:params:jmap:submission"},
		MethodCalls: methodCalls,
	}
	
	jsonData, err := json.Marshal(request)
	if err != nil {
		return nil, err
	}
	
	req, err := http.NewRequest("POST", session.APIURL, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}
	
	req.Header.Set("Authorization", "Bearer "+apiToken)
	req.Header.Set("Content-Type", "application/json")
	
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
	}
	
	var jmapResp JMAPResponse
	if err := json.NewDecoder(resp.Body).Decode(&jmapResp); err != nil {
		return nil, err
	}
	
	return &jmapResp, nil
}

func listMailboxes(cmd *cobra.Command) {
	accountID := getAccountID()
	
	methodCalls := []interface{}{
		[]interface{}{
			"Mailbox/get",
			map[string]interface{}{
				"accountId": accountID,
			},
			"0",
		},
	}
	
	resp, err := makeJMAPRequest(methodCalls)
	if err != nil {
		outputError(fmt.Sprintf("Failed to get mailboxes: %v", err))
		return
	}
	
	if len(resp.MethodResponses) == 0 {
		outputError("No response from server")
		return
	}
	
	methodResp := resp.MethodResponses[0].([]interface{})
	if len(methodResp) < 2 {
		outputError("Invalid response format")
		return
	}
	
	data := methodResp[1].(map[string]interface{})
	mailboxes := data["list"].([]interface{})
	
	var result []Mailbox
	for _, mb := range mailboxes {
		mbMap := mb.(map[string]interface{})
		mailbox := Mailbox{
			ID:   mbMap["id"].(string),
			Name: mbMap["name"].(string),
		}
		if parentID, ok := mbMap["parentId"]; ok && parentID != nil {
			mailbox.ParentID = parentID.(string)
		}
		if role, ok := mbMap["role"]; ok && role != nil {
			mailbox.Role = role.(string)
		}
		if total, ok := mbMap["totalEmails"]; ok {
			mailbox.TotalEmails = int(total.(float64))
		}
		if unread, ok := mbMap["unreadEmails"]; ok {
			mailbox.UnreadEmails = int(unread.(float64))
		}
		result = append(result, mailbox)
	}
	
	outputSuccess(result)
}

func listEmails(cmd *cobra.Command) {
	accountID := getAccountID()
	limit, _ := cmd.Flags().GetInt("limit")
	if limit == 0 {
		limit = 50
	}
	
	mailbox, _ := cmd.Flags().GetString("mailbox")
	if mailbox == "" {
		mailbox = "INBOX"
	}
	
	// First get the mailbox ID
	mailboxID, err := getMailboxID(mailbox)
	if err != nil {
		outputError(fmt.Sprintf("Failed to find mailbox '%s': %v", mailbox, err))
		return
	}
	
	methodCalls := []interface{}{
		[]interface{}{
			"Email/query",
			map[string]interface{}{
				"accountId": accountID,
				"filter": map[string]interface{}{
					"inMailbox": mailboxID,
				},
				"sort": []map[string]interface{}{
					{"property": "receivedAt", "isAscending": false},
				},
				"limit": limit,
			},
			"0",
		},
		[]interface{}{
			"Email/get",
			map[string]interface{}{
				"accountId": accountID,
				"#ids": map[string]interface{}{
					"resultOf": "0",
					"name":     "Email/query",
					"path":     "/ids",
				},
				"properties": []string{
					"id", "threadId", "mailboxIds", "keywords", "size",
					"receivedAt", "from", "to", "subject", "preview", "hasAttachment",
				},
			},
			"1",
		},
	}
	
	resp, err := makeJMAPRequest(methodCalls)
	if err != nil {
		outputError(fmt.Sprintf("Failed to get emails: %v", err))
		return
	}
	
	if len(resp.MethodResponses) < 2 {
		outputError("Incomplete response from server")
		return
	}
	
	emailResp := resp.MethodResponses[1].([]interface{})
	data := emailResp[1].(map[string]interface{})
	emails := data["list"].([]interface{})
	
	var result []Email
	for _, email := range emails {
		emailMap := email.(map[string]interface{})
		
		e := Email{
			ID:       emailMap["id"].(string),
			ThreadID: emailMap["threadId"].(string),
			Subject:  getString(emailMap, "subject"),
			Preview:  getString(emailMap, "preview"),
		}
		
		if size, ok := emailMap["size"]; ok {
			e.Size = int(size.(float64))
		}
		
		if receivedAt, ok := emailMap["receivedAt"]; ok {
			if t, err := time.Parse(time.RFC3339, receivedAt.(string)); err == nil {
				e.ReceivedAt = t
			}
		}
		
		if hasAttach, ok := emailMap["hasAttachment"]; ok {
			e.HasAttachment = hasAttach.(bool)
		}
		
		if from, ok := emailMap["from"]; ok {
			e.From = parseEmailAddresses(from.([]interface{}))
		}
		
		if to, ok := emailMap["to"]; ok {
			e.To = parseEmailAddresses(to.([]interface{}))
		}
		
		if keywords, ok := emailMap["keywords"]; ok {
			e.Keywords = make(map[string]bool)
			for k, v := range keywords.(map[string]interface{}) {
				e.Keywords[k] = v.(bool)
			}
		}
		
		result = append(result, e)
	}
	
	outputSuccess(result)
}

func getEmail(emailID string) {
	accountID := getAccountID()
	
	methodCalls := []interface{}{
		[]interface{}{
			"Email/get",
			map[string]interface{}{
				"accountId": accountID,
				"ids":       []string{emailID},
				"properties": []string{
					"id", "threadId", "mailboxIds", "keywords", "size",
					"receivedAt", "from", "to", "cc", "bcc", "subject",
					"preview", "hasAttachment", "textBody", "htmlBody", "headers",
				},
			},
			"0",
		},
	}
	
	resp, err := makeJMAPRequest(methodCalls)
	if err != nil {
		outputError(fmt.Sprintf("Failed to get email: %v", err))
		return
	}
	
	if len(resp.MethodResponses) == 0 {
		outputError("No response from server")
		return
	}
	
	methodResp, ok := resp.MethodResponses[0].([]interface{})
	if !ok {
		outputError("Invalid response format: method response is not an array")
		return
	}
	
	if len(methodResp) < 2 {
		outputError("Invalid response format: insufficient response data")
		return
	}
	
	// Check if this is an error response
	if methodName, ok := methodResp[0].(string); ok && methodName == "error" {
		outputError(fmt.Sprintf("JMAP error: %v", methodResp[1]))
		return
	}
	
	data, ok := methodResp[1].(map[string]interface{})
	if !ok {
		outputError("Invalid response format: response data is not a map")
		return
	}
	
	emailsList, ok := data["list"].([]interface{})
	if !ok {
		outputError("Invalid response format: email list is not an array")
		return
	}
	
	if len(emailsList) == 0 {
		outputError("Email not found")
		return
	}
	
	emailMap, ok := emailsList[0].(map[string]interface{})
	if !ok {
		outputError("Invalid response format: email data is not a map")
		return
	}
	
	email := Email{
		ID:       getString(emailMap, "id"),
		ThreadID: getString(emailMap, "threadId"),
		Subject:  getString(emailMap, "subject"),
		Preview:  getString(emailMap, "preview"),
	}
	
	if size, ok := emailMap["size"]; ok {
		if sizeFloat, ok := size.(float64); ok {
			email.Size = int(sizeFloat)
		}
	}
	
	if receivedAt, ok := emailMap["receivedAt"]; ok {
		if receivedAtStr, ok := receivedAt.(string); ok {
			if t, err := time.Parse(time.RFC3339, receivedAtStr); err == nil {
				email.ReceivedAt = t
			}
		}
	}
	
	if hasAttach, ok := emailMap["hasAttachment"]; ok {
		if hasAttachBool, ok := hasAttach.(bool); ok {
			email.HasAttachment = hasAttachBool
		}
	}
	
	if from, ok := emailMap["from"]; ok && from != nil {
		if fromArray, ok := from.([]interface{}); ok {
			email.From = parseEmailAddresses(fromArray)
		}
	}
	
	if to, ok := emailMap["to"]; ok && to != nil {
		if toArray, ok := to.([]interface{}); ok {
			email.To = parseEmailAddresses(toArray)
		}
	}
	
	if cc, ok := emailMap["cc"]; ok && cc != nil {
		if ccArray, ok := cc.([]interface{}); ok {
			email.CC = parseEmailAddresses(ccArray)
		}
	}
	
	if bcc, ok := emailMap["bcc"]; ok && bcc != nil {
		if bccArray, ok := bcc.([]interface{}); ok {
			email.BCC = parseEmailAddresses(bccArray)
		}
	}
	
	if keywords, ok := emailMap["keywords"]; ok && keywords != nil {
		if keywordsMap, ok := keywords.(map[string]interface{}); ok {
			email.Keywords = make(map[string]bool)
			for k, v := range keywordsMap {
				if vBool, ok := v.(bool); ok {
					email.Keywords[k] = vBool
				}
			}
		}
	}
	
	if headers, ok := emailMap["headers"]; ok && headers != nil {
		if headersMap, ok := headers.(map[string]interface{}); ok {
			email.Headers = make(map[string]string)
			for k, v := range headersMap {
				if vStr, ok := v.(string); ok {
					email.Headers[k] = vStr
				}
			}
		}
	}
	
	outputSuccess(email)
}

func searchEmails(query string) {
	accountID := getAccountID()
	
	methodCalls := []interface{}{
		[]interface{}{
			"Email/query",
			map[string]interface{}{
				"accountId": accountID,
				"filter": map[string]interface{}{
					"text": query,
				},
				"sort": []map[string]interface{}{
					{"property": "receivedAt", "isAscending": false},
				},
				"limit": 50,
			},
			"0",
		},
		[]interface{}{
			"Email/get",
			map[string]interface{}{
				"accountId": accountID,
				"#ids": map[string]interface{}{
					"resultOf": "0",
					"name":     "Email/query",
					"path":     "/ids",
				},
				"properties": []string{
					"id", "threadId", "mailboxIds", "keywords", "size",
					"receivedAt", "from", "to", "subject", "preview", "hasAttachment",
				},
			},
			"1",
		},
	}
	
	resp, err := makeJMAPRequest(methodCalls)
	if err != nil {
		outputError(fmt.Sprintf("Failed to search emails: %v", err))
		return
	}
	
	if len(resp.MethodResponses) < 2 {
		outputError("Incomplete response from server")
		return
	}
	
	emailResp := resp.MethodResponses[1].([]interface{})
	data := emailResp[1].(map[string]interface{})
	emails := data["list"].([]interface{})
	
	var result []Email
	for _, email := range emails {
		emailMap := email.(map[string]interface{})
		
		e := Email{
			ID:       emailMap["id"].(string),
			ThreadID: emailMap["threadId"].(string),
			Subject:  getString(emailMap, "subject"),
			Preview:  getString(emailMap, "preview"),
		}
		
		if size, ok := emailMap["size"]; ok {
			e.Size = int(size.(float64))
		}
		
		if receivedAt, ok := emailMap["receivedAt"]; ok {
			if t, err := time.Parse(time.RFC3339, receivedAt.(string)); err == nil {
				e.ReceivedAt = t
			}
		}
		
		if hasAttach, ok := emailMap["hasAttachment"]; ok {
			e.HasAttachment = hasAttach.(bool)
		}
		
		if from, ok := emailMap["from"]; ok {
			e.From = parseEmailAddresses(from.([]interface{}))
		}
		
		if to, ok := emailMap["to"]; ok {
			e.To = parseEmailAddresses(to.([]interface{}))
		}
		
		result = append(result, e)
	}
	
	outputSuccess(map[string]interface{}{
		"query":   query,
		"results": len(result),
		"emails":  result,
	})
}

func getAccountID() string {
	if session != nil && len(session.PrimaryAccounts) > 0 {
		return session.PrimaryAccounts["urn:ietf:params:jmap:mail"]
	}
	return ""
}

func getMailboxID(name string) (string, error) {
	accountID := getAccountID()
	
	methodCalls := []interface{}{
		[]interface{}{
			"Mailbox/get",
			map[string]interface{}{
				"accountId": accountID,
			},
			"0",
		},
	}
	
	resp, err := makeJMAPRequest(methodCalls)
	if err != nil {
		return "", err
	}
	
	if len(resp.MethodResponses) == 0 {
		return "", fmt.Errorf("no response from server")
	}
	
	methodResp := resp.MethodResponses[0].([]interface{})
	data := methodResp[1].(map[string]interface{})
	mailboxes := data["list"].([]interface{})
	
	for _, mb := range mailboxes {
		mbMap := mb.(map[string]interface{})
		mbName := mbMap["name"].(string)
		if strings.EqualFold(mbName, name) || (name == "INBOX" && mbMap["role"] == "inbox") {
			return mbMap["id"].(string), nil
		}
	}
	
	return "", fmt.Errorf("mailbox '%s' not found", name)
}

func parseEmailAddresses(addresses []interface{}) []EmailAddress {
	var result []EmailAddress
	for _, addr := range addresses {
		addrMap := addr.(map[string]interface{})
		ea := EmailAddress{
			Email: addrMap["email"].(string),
		}
		if name, ok := addrMap["name"]; ok && name != nil {
			ea.Name = name.(string)
		}
		result = append(result, ea)
	}
	return result
}

func getString(m map[string]interface{}, key string) string {
	if val, ok := m[key]; ok && val != nil {
		return val.(string)
	}
	return ""
}

func outputSuccess(data interface{}) {
	output := CLIOutput{
		Success: true,
		Data:    data,
	}
	json.NewEncoder(os.Stdout).Encode(output)
}

func outputError(message string) {
	output := CLIOutput{
		Success: false,
		Error:   message,
	}
	json.NewEncoder(os.Stderr).Encode(output)
}

func init() {
	listCmd.Flags().Int("limit", 50, "Maximum number of emails to retrieve")
	listCmd.Flags().String("mailbox", "INBOX", "Mailbox to list emails from")
	
	sendCmd.Flags().String("to", "", "Recipient email address(es), comma-separated")
	sendCmd.Flags().String("subject", "", "Email subject")
	sendCmd.Flags().String("body", "", "Email body text")
	sendCmd.Flags().String("cc", "", "CC email address(es), comma-separated")
	sendCmd.Flags().String("bcc", "", "BCC email address(es), comma-separated")
	sendCmd.MarkFlagRequired("to")
	sendCmd.MarkFlagRequired("subject")
	sendCmd.MarkFlagRequired("body")
}

func sendEmail(to, subject, body, cc, bcc string) {
	accountID := getAccountID()
	
	// Parse email addresses
	toAddresses := parseEmailAddressString(to)
	var ccAddresses, bccAddresses []EmailAddress
	
	if cc != "" {
		ccAddresses = parseEmailAddressString(cc)
	}
	if bcc != "" {
		bccAddresses = parseEmailAddressString(bcc)
	}
	
	// Get user's identity
	identity, err := getDefaultIdentity(accountID)
	if err != nil {
		outputError(fmt.Sprintf("Failed to get identity: %v", err))
		return
	}
	
	// Upload email body as blob
	blobID, err := uploadBlob(body, accountID)
	if err != nil {
		outputError(fmt.Sprintf("Failed to upload email body: %v", err))
		return
	}
	
	// Create email object for sending
	emailCreate := map[string]interface{}{
		"from":    []map[string]string{{"email": identity.Email, "name": identity.Name}},
		"to":      emailAddressesToMap(toAddresses),
		"subject": subject,
		"textBody": []map[string]interface{}{{
			"type":   "text/plain",
			"partId": "text",
			"blobId": blobID,
		}},
		"keywords": map[string]bool{"$seen": true, "$draft": false},
	}
	
	if len(ccAddresses) > 0 {
		emailCreate["cc"] = emailAddressesToMap(ccAddresses)
	}
	if len(bccAddresses) > 0 {
		emailCreate["bcc"] = emailAddressesToMap(bccAddresses)
	}
	
	// Create and send email
	methodCalls := []interface{}{
		[]interface{}{
			"Email/set",
			map[string]interface{}{
				"accountId": accountID,
				"create": map[string]interface{}{
					"draft": emailCreate,
				},
			},
			"0",
		},
		[]interface{}{
			"EmailSubmission/set",
			map[string]interface{}{
				"accountId": accountID,
				"create": map[string]interface{}{
					"submission": map[string]interface{}{
						"identityId": identity.ID,
						"emailId": map[string]interface{}{
							"resultOf": "0",
							"name":     "Email/set",
							"path":     "/created/draft/id",
						},
					},
				},
			},
			"1",
		},
	}
	
	resp, err := makeJMAPRequest(methodCalls)
	if err != nil {
		outputError(fmt.Sprintf("Failed to send email: %v", err))
		return
	}
	
	if len(resp.MethodResponses) < 2 {
		outputError("Incomplete response from server")
		return
	}
	
	// Check for errors
	emailResp := resp.MethodResponses[0].([]interface{})
	if emailResp[0].(string) == "error" {
		outputError(fmt.Sprintf("Email creation failed: %v", emailResp[1]))
		return
	}
	
	submissionResp := resp.MethodResponses[1].([]interface{})
	if submissionResp[0].(string) == "error" {
		outputError(fmt.Sprintf("Email submission failed: %v", submissionResp[1]))
		return
	}
	
	outputSuccess(map[string]interface{}{
		"message": "Email sent successfully",
		"to":      to,
		"subject": subject,
	})
}

func getDefaultIdentity(accountID string) (*Identity, error) {
	methodCalls := []interface{}{
		[]interface{}{
			"Identity/get",
			map[string]interface{}{
				"accountId": accountID,
			},
			"0",
		},
	}
	
	resp, err := makeJMAPRequest(methodCalls)
	if err != nil {
		return nil, err
	}
	
	if len(resp.MethodResponses) == 0 {
		return nil, fmt.Errorf("no response from server")
	}
	
	methodResp := resp.MethodResponses[0].([]interface{})
	if methodResp[0].(string) == "error" {
		return nil, fmt.Errorf("JMAP error: %v", methodResp[1])
	}
	
	data := methodResp[1].(map[string]interface{})
	identities := data["list"].([]interface{})
	
	if len(identities) == 0 {
		return nil, fmt.Errorf("no identities found")
	}
	
	// Use the first identity
	identityMap := identities[0].(map[string]interface{})
	identity := &Identity{
		ID:    identityMap["id"].(string),
		Email: identityMap["email"].(string),
	}
	
	if name, ok := identityMap["name"]; ok && name != nil {
		identity.Name = name.(string)
	}
	
	return identity, nil
}

func uploadBlob(content string, accountID string) (string, error) {
	uploadURL := session.UploadURL + "?accountId=" + accountID
	req, err := http.NewRequest("POST", uploadURL, strings.NewReader(content))
	if err != nil {
		return "", err
	}
	
	req.Header.Set("Authorization", "Bearer "+apiToken)
	req.Header.Set("Content-Type", "text/plain; charset=utf-8")
	
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
	}
	
	var uploadResp struct {
		BlobID string `json:"blobId"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&uploadResp); err != nil {
		return "", err
	}
	
	return uploadResp.BlobID, nil
}

func parseEmailAddressString(addresses string) []EmailAddress {
	var result []EmailAddress
	
	for _, addr := range strings.Split(addresses, ",") {
		addr = strings.TrimSpace(addr)
		if addr != "" {
			result = append(result, EmailAddress{Email: addr})
		}
	}
	
	return result
}

func emailAddressesToMap(addresses []EmailAddress) []map[string]string {
	var result []map[string]string
	
	for _, addr := range addresses {
		addrMap := map[string]string{"email": addr.Email}
		if addr.Name != "" {
			addrMap["name"] = addr.Name
		}
		result = append(result, addrMap)
	}
	
	return result
}