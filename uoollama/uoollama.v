module uoollama

import net.http
import x.json2
import time
import h_sys_2025.uoollama.skillmaker { Skills }

// Generate full system prompt (bio + skills)
pub fn gen_sys_prompt(skills Skills, bio string) string {
  mut sys_prompt := bio
  sys_prompt += "\n${skills.fmt_skills_and_guidelines()}"
  return sys_prompt
}

pub struct Message {
  role    string
  content string
}

pub struct OllamaRequest {
  pub mut:
    model      string
    prompt     string
    stream     bool
    think      bool
    sys_prompt string
    messages   []Message // for chat history
}

pub struct OllamaResponse {
  model    string
  response string
  pub mut:
    time_taken i64
    done       bool
}

pub struct ChatPayload {
  pub mut:
    model string
    messages []Message
    stream bool
}

// Legacy single-prompt completion
pub fn (req OllamaRequest) completion() OllamaResponse {
  start_time := time.now().unix()
  json_data := json2.encode(req)

  headers := http.new_header_from_map({
    http.CommonHeader.content_type: "application/json"
  })

  conf := http.FetchConfig{
    method: .post
    url:    "http://localhost:11434/api/generate"
    header: headers
    data:   json_data
  }

  resp := http.fetch(conf) or {
    println("Request failed: ${err}")
    return OllamaResponse{}
  }

  mut result := json2.decode[OllamaResponse](resp.body) or {
    println("JSON decode failed: ${err}")
    return OllamaResponse{response: resp.body}
  }

  result.time_taken = time.now().unix() - start_time
  return result
}

// New: Full chat completion with messages + system prompt
pub fn (req OllamaRequest) chat_completion() OllamaResponse {
  start_time := time.now().unix()

  mut msgs := req.messages.clone()

  // Prepend system prompt if set
  if req.sys_prompt != "" {
    msgs.prepend(Message{
      role:    "system"
      content: req.sys_prompt
    })
  }

  // Add current user prompt
  if req.prompt != "" {
    msgs << Message{
      role:    "user"
      content: req.prompt
    }
  }

  chat_payload := ChatPayload{
    model:    req.model
    messages: msgs
    stream:   req.stream
  }

  json_data := json2.encode(chat_payload)
    headers := http.new_header_from_map({
      http.CommonHeader.content_type: "application/json"
    })

  conf := http.FetchConfig{
    method: .post
    url:    "http://localhost:11434/api/chat"
    header: headers
    data:   json_data
  }

  resp := http.fetch(conf) or {
    println("Chat request failed: ${err}")
    return OllamaResponse{}
  }

  mut result := json2.decode[OllamaResponse](resp.body) or {
    println("JSON decode failed for chat: ${err}")
    return OllamaResponse{response: resp.body}
  }

  result.time_taken = time.now().unix() - start_time
  return result
}

// List available models
pub struct OllamaModel {
  name        string
  size        i64
  digest      string
  modified_at string
}

pub struct OllamaModels {
  models []OllamaModel
}

pub fn list_ollama_models() (OllamaModels, string) {
  resp := http.get("http://localhost:11434/api/tags") or {
    return OllamaModels{}, "Request error"
  }
  if resp.status_code != 200 {
    return OllamaModels{}, "Error: status code ${resp.status_code}"
  }
  data := json2.decode[OllamaModels](resp.body) or {
    return OllamaModels{}, "Error parsing JSON"
  }
  return data, ""
}

// Set model with validation
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
  return false, "Model '${model_name}' does not exist. Use list_ollama_models() to see available ones."
}

// Convenience methods
pub fn (mut req OllamaRequest) prompt_complete(prompt string) OllamaResponse {
  req.prompt = prompt
  return req.completion()
}

pub fn (mut req OllamaRequest) chat(prompt string) OllamaResponse {
  req.prompt = prompt
  return req.chat_completion()
}

pub fn (resp OllamaResponse) print() {
  println("Model     : ${resp.model}")
  println("Time      : ${resp.time_taken} second(s)")
  println("Done      : ${resp.done}")
  println("Response  :\n${resp.response}")
}

// Example usage
// fn main() {
//   mut req := OllamaRequest{
//     model:      "llama3.2"
//     stream:     false
//     sys_prompt: "You are a helpful assistant that follows tool usage rules strictly."
//   }

//   resp := req.chat("Why is the sky blue? Answer briefly.")
//   resp.print()
// }