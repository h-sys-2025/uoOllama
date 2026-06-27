# Easy to use (and un-official) lib to use selfhosted ollama models, in v..
- Very simple lib:
- - With basic Ollama connection, and skills maker system something idk.
- This is a MICRO-LIB, onsists of very few functions, and can be used in small projects, and nothing more.

![0.3](https://img.shields.io/badge/version-0.2.5-white?style=flat)
![GitHub](https://img.shields.io/badge/license-MIT-blue?style=flat)
![vlang](http://img.shields.io/badge/V-0.5+-%236d8fc5?style=flat)

## Installazation:
```v
v install h-sys-2025.uoOllama
```
### It contains:
```v
import h_sys_2025.uoollama.uoollama { OllamaRequest } // for basic ollama connection.
import h_sys_2025.uoollama.skillmaker { Skills }      // skillssssss.
```

## Example:
```v
module main

import h_sys_2025.uoollama.uoollama { OllamaRequest, gen_sys_prompt }
import h_sys_2025.uoollama.skillmaker { Skills }
import os

// ---------------------------------------------------------------------------
// Real executors (swap stubs for actual logic here)
// ---------------------------------------------------------------------------

fn exec_bash(args map[string]string) string {
  cmd     := args["command"] or { return "Error: missing command" }
  timeout := args["timeout"] or { "30000" }
  // Uncomment to actually run:
  // result := os.execute(cmd)
  // return result.output
  return "[bash] ran: `${cmd}` (timeout=${timeout}ms) → exit 0"
}

fn exec_weather(args map[string]string) string {
  city  := args["city"]  or { return "Error: missing city" }
  units := args["units"] or { "metric" }
  // Swap with a real HTTP call to a weather API here.
  return "[weather] ${city}: 24°C, humidity 60%, ${units} units"
}

fn exec_read_file(args map[string]string) string {
  path := args["path"] or { return "Error: missing path" }
  return os.read_file(path) or { "Error reading file: ${err}" }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
  mut skills := Skills{}

  skills.new_skill(
    "bash",
    "Run a shell command and return stdout.",
    ["command:string", "timeout:milliseconds"],
    exec_bash,
  )

  skills.new_skill(
    "weather",
    "Get current weather for a city.",
    ["city:string", "units:string"],
    exec_weather,
  )

  skills.new_skill(
    "read_file",
    "Read a file from disk and return its contents.",
    ["path:string"],
    exec_read_file,
  )

  bio := "You are a concise, tool-driven assistant.\n" +
         "Always use a tool when one is available rather than guessing."

  sys_prompt := gen_sys_prompt(skills, bio)

  mut req := OllamaRequest{
    model:      "huihui_ai/qwen2.5-coder-abliterate:3b-instruct-q4_K_M-strict"
    sys_prompt: sys_prompt
    stream:     false
  }

  // Optional — validate the model exists before sending:
  // ok, errmsg := req.set_model(req.model)
  // if !ok { eprintln("Model error: ${errmsg}") return }

  println(" Demo A — single chat turn + manual parse")

  resp_a := req.chat("What''s the weather in Tokyo?")
  println("\n[raw response]\n${resp_a.response}")

  parsed_a := skills.parse(resp_a.response)

  if parsed_a.plain_text() != "" {
    println("\n[assistant text]\n${parsed_a.plain_text()}")
  }

  if parsed_a.tool_calls.len > 0 {
    println("\n[tool calls detected]\n${parsed_a.fmt_parsed()}")
    println("\n[tool results]\n${skills.execute_all(parsed_a)}")
  } else {
    println("\n(no tool calls detected)")
  }

  // run_agent handles parse → execute → feed-back automatically,
  // looping until the model stops emitting tool calls.
  println(" Demo B — agentic loop (auto tool use)")

  result := req.run_agent(
    "Check the weather in London and also list the files in /tmp with bash.",
    skills,
    5, // max rounds before giving up
  )

  println("\n[final response after ${result.rounds} round(s)]\n${result.final_response}")
  println("\n[conversation history — ${result.history.len} messages]")
  for i, m in result.history {
    preview := if m.content.len > 80 { m.content[..80] + "…" } else { m.content }
    println("  ${i + 1}. [${m.role}] ${preview}")
  }

  println(" Demo C — follow-up turn with history")

  // Reuse history from the agent run so context is preserved.
  req.messages = result.history
  follow_up := req.chat("Now check the weather in Paris too.")
  println("\n[follow-up response]\n${follow_up.response}")

  parsed_c := skills.parse(follow_up.response)
  if parsed_c.tool_calls.len > 0 {
    println("\n[tool results]\n${skills.execute_all(parsed_c)}")
  }
}
```
