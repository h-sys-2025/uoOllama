module uoollama

import net.http
import x.json2
import time
import h_sys_2025.uoollama.skillmaker { Skills, ToolCall }

// ---------------------------------------------------------------------------
// Prompt helpers
// ---------------------------------------------------------------------------

// Build a full system prompt from bio + skills block.
pub fn gen_sys_prompt(skills Skills, bio string) string {
  return bio + "\n" + skills.fmt_skills_and_guidelines()
}

// ---------------------------------------------------------------------------
// Wire types
// ---------------------------------------------------------------------------

pub struct Message {
pub mut:
  role    string
  content string
}

// OllamaRequest holds everything needed for a single chat turn.
pub struct OllamaRequest {
pub mut:
  model      string
  prompt     string
  stream     bool
  think      bool
  sys_prompt string
  messages   []Message // running conversation history (user + assistant only)
}

// ---------------------------------------------------------------------------
// /api/chat response — Ollama wraps the reply inside a "message" object.
// ---------------------------------------------------------------------------

struct ChatMessage {
pub mut:
  role    string
  content string
}

struct ChatResponse {
pub mut:
  model      string
  message    ChatMessage
  done       bool
  time_taken i64 // filled in by us, not Ollama
}

// OllamaResponse is the public-facing result type.
pub struct OllamaResponse {
pub mut:
  model      string
  response   string // the assistant text
  done       bool
  time_taken i64
}

// ---------------------------------------------------------------------------
// /api/generate response (legacy single-shot endpoint)
// ---------------------------------------------------------------------------

struct GenerateResponse {
pub mut:
  model      string
  response   string
  done       bool
  time_taken i64
}

// ---------------------------------------------------------------------------
// Internal HTTP helper
// ---------------------------------------------------------------------------

fn post_json(url string, payload string) !string {
  headers := http.new_header_from_map({
    http.CommonHeader.content_type: "application/json"
  })
  conf := http.FetchConfig{
    method: .post
    url:    url
    header: headers
    data:   payload
  }
  resp := http.fetch(conf)!
  return resp.body
}

// ---------------------------------------------------------------------------
// chat_completion  (/api/chat)
//
// System prompt is injected as the very first message with role "system"
// so every model that supports it can pick it up, regardless of whether
// it honours a top-level "system" field.
// ---------------------------------------------------------------------------

pub fn (req OllamaRequest) chat_completion() OllamaResponse {
  start := time.now().unix()

  mut msgs := []Message{}

  // 1. System prompt → first message (role = "system")
  if req.sys_prompt != "" {
    msgs << Message{
      role:    "system"
      content: req.sys_prompt
    }
  }

  // 2. Existing conversation history
  msgs << req.messages

  // 3. Current user turn
  if req.prompt != "" {
    msgs << Message{
      role:    "user"
      content: req.prompt
    }
  }

  payload := json2.encode({
    "model":    json2.Any(req.model)
    "stream":   json2.Any(false)
    "messages": json2.Any(msgs.map(fn (m Message) json2.Any {
      return json2.Any({
        "role":    json2.Any(m.role)
        "content": json2.Any(m.content)
      })
    }))
  })

  body := post_json("http://localhost:11434/api/chat", payload) or {
    eprintln("[uoollama] chat request failed: ${err}")
    return OllamaResponse{}
  }

  raw := json2.decode[ChatResponse](body) or {
    eprintln("[uoollama] JSON decode failed: ${err}\nraw: ${body}")
    return OllamaResponse{
      response: body
    }
  }

  return OllamaResponse{
    model:      raw.model
    response:   raw.message.content
    done:       raw.done
    time_taken: time.now().unix() - start
  }
}

// ---------------------------------------------------------------------------
// completion  (/api/generate) — legacy single-shot, kept for compatibility
// ---------------------------------------------------------------------------

pub fn (req OllamaRequest) completion() OllamaResponse {
  start := time.now().unix()

  payload := json2.encode({
    "model":      json2.Any(req.model)
    "prompt":     json2.Any(req.prompt)
    "system":     json2.Any(req.sys_prompt)
    "stream":     json2.Any(false)
  })

  body := post_json("http://localhost:11434/api/generate", payload) or {
    eprintln("[uoollama] generate request failed: ${err}")
    return OllamaResponse{}
  }

  raw := json2.decode[GenerateResponse](body) or {
    eprintln("[uoollama] JSON decode failed: ${err}")
    return OllamaResponse{response: body}
  }

  return OllamaResponse{
    model:      raw.model
    response:   raw.response
    done:       raw.done
    time_taken: time.now().unix() - start
  }
}

// ---------------------------------------------------------------------------
// Model listing & validation
// ---------------------------------------------------------------------------

pub struct OllamaModel {
pub:
  name        string
  size        i64
  digest      string
  modified_at string
}

pub struct OllamaModels {
pub:
  models []OllamaModel
}

pub fn list_ollama_models() (OllamaModels, string) {
  resp := http.get("http://localhost:11434/api/tags") or {
    return OllamaModels{}, "Request error: ${err}"
  }
  if resp.status_code != 200 {
    return OllamaModels{}, "Error: HTTP ${resp.status_code}"
  }
  data := json2.decode[OllamaModels](resp.body) or {
    return OllamaModels{}, "JSON parse error: ${err}"
  }
  return data, ""
}

pub fn (mut req OllamaRequest) set_model(model_name string) (bool, string) {
  models_, err := list_ollama_models()
  if err != "" {
    return false, err
  }
  for m in models_.models {
    if m.name == model_name {
      req.model = model_name
      return true, ""
    }
  }
  return false, "Model '${model_name}' not found. Available: ${models_.models.map(it.name).join(", ")}"
}

// ---------------------------------------------------------------------------
// Convenience wrappers
// ---------------------------------------------------------------------------

pub fn (mut req OllamaRequest) prompt_complete(prompt string) OllamaResponse {
  req.prompt = prompt
  return req.completion()
}

pub fn (mut req OllamaRequest) chat(prompt string) OllamaResponse {
  req.prompt = prompt
  return req.chat_completion()
}

pub fn (resp OllamaResponse) print() {
  println("Model      : ${resp.model}")
  println("Time       : ${resp.time_taken}s")
  println("Done       : ${resp.done}")
  println("Response   :\n${resp.response}")
}

// ---------------------------------------------------------------------------
// Agentic loop
//
// Runs a full tool-use cycle:
//   1. Send user prompt → get assistant reply
//   2. Parse any <tool_call> blocks
//   3. Execute each tool, collect results
//   4. Feed results back as a "tool" message and loop
//   5. Stop when no tool calls remain (or max_rounds reached)
//
// History is kept internally and returned so callers can persist it.
// ---------------------------------------------------------------------------

pub struct AgentResult {
pub:
  final_response string
  history        []Message
  rounds         int
}

pub fn (mut req OllamaRequest) run_agent(prompt string, skills Skills, max_rounds int) AgentResult {
  mut history := req.messages.clone()
  mut current_prompt := prompt
  mut rounds := 0

  for rounds < max_rounds {
    // Build a temporary request with current history
    mut turn := OllamaRequest{
      model:      req.model
      sys_prompt: req.sys_prompt
      stream:     false
      messages:   history
      prompt:     current_prompt
    }

    resp := turn.chat_completion()
    if resp.response == "" {
      break
    }

    // Record the assistant turn in history
    history << Message{role: "user", content: current_prompt}
    history << Message{role: "assistant", content: resp.response}

    // Parse tool calls
    parsed := skills.parse(resp.response)
    if parsed.tool_calls.len == 0 {
      // No tools needed — we"re done
      req.messages = history
      return AgentResult{
        final_response: resp.response
        history:        history
        rounds:         rounds + 1
      }
    }

    // Execute every tool call and collect results
    mut tool_results := ""
    for tc in parsed.tool_calls {
      result := skills.execute_tool(tc)
      tool_results += "<tool_result name=\"${tc.name}\">\n${result}\n</tool_result>\n"
    }

    // Feed results back as the next user turn
    current_prompt = tool_results.trim_space()
    rounds++
  }

  // Reached max_rounds — return whatever history we have
  req.messages = history
  last_assistant := history.filter(it.role == "assistant").last()
  return AgentResult{
    final_response: last_assistant.content
    history:        history
    rounds:         rounds
  }
}