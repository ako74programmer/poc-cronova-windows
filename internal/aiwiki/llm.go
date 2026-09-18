package aiwiki

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/zoyluo/cronova/internal/model"
)

// LLMClient calls an OpenAI-compatible chat completions endpoint.
type LLMClient struct {
	provider *model.AIProvider
	client   *http.Client
}

// NewLLMClient creates a client for the given provider.
func NewLLMClient(p *model.AIProvider) *LLMClient {
	return &LLMClient{
		provider: p,
		client:   &http.Client{Timeout: 60 * time.Second},
	}
}

// GenerateAnswer asks the LLM to answer the question using the provided context chunks.
func (c *LLMClient) GenerateAnswer(ctx context.Context, question string, chunks []Chunk) (string, error) {
	if c.provider == nil {
		return "", fmt.Errorf("no AI provider configured")
	}

	var contextText string
	for _, ch := range chunks {
		contextText += fmt.Sprintf("---\nSource: %s\nSection: %s\n%s\n", ch.Source, ch.Section, ch.Text)
	}

	var systemPrompt string
	var userPrompt string
	if contextText == "" {
		systemPrompt = `You are a helpful assistant inside the cronova workflow scheduler console.
The user's question is not covered by the cronova documentation, so answer from your general knowledge.
Keep the answer concise (2-4 sentences).
Answer in the same language as the user's question.`
		userPrompt = fmt.Sprintf("Question: %s\n\nAnswer:", question)
	} else {
		systemPrompt = `You are a helpful assistant for the cronova workflow scheduler.
Answer the user's question based ONLY on the provided context.
Keep the answer concise (2-4 sentences).
If the context does not contain the answer, say "I don't have that information."
Answer in the same language as the user's question.
When the context mentions YAML fields, explain how to use them in a DAG definition.`
		userPrompt = fmt.Sprintf("Context:\n%s\n\nQuestion: %s\n\nAnswer:", contextText, question)
	}

	reqBody := map[string]any{
		"model": c.provider.Model,
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": userPrompt},
		},
		"temperature": 0.3,
	}
	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}

	url := c.provider.BaseURL

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	if c.provider.Token != "" {
		req.Header.Set("Authorization", "Bearer "+c.provider.Token)
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("LLM returned %d: %s", resp.StatusCode, string(respBody))
	}

	var result struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", err
	}
	if len(result.Choices) == 0 {
		return "", fmt.Errorf("no choices in LLM response")
	}
	return result.Choices[0].Message.Content, nil
}
