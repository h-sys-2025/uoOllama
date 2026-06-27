module skillmaker

import strings

// ---------------------------------------------------------------------------
// Arg / Usage
// ---------------------------------------------------------------------------

struct Arg {
pub mut:
  name  string
  dtype string
}

struct Usage {
  args       []Arg
  args_count int
  help       string
}

fn help_build(name string, args []Arg) string {
  mut sb := strings.new_builder(256)
  sb.write_string('<tool_call name="${name}">\n')
  for a in args {
    sb.write_string('  ${a.name} = VALUE_OF_TYPE(${a.dtype})_HERE\n')
  }
  sb.write_string('</tool_call>')
  return sb.str()
}

fn usage_build(name string, args []string) Usage {
  mut arguments := []Arg{}
  for x in args {
    parts := x.split(':')
    arguments << if parts.len == 2 {
      Arg{name: parts[0], dtype: parts[1]}
    } else {
      Arg{name: x, dtype: 'any'}
    }
  }
  return Usage{
    args:       arguments
    args_count: arguments.len
    help:       help_build(name, arguments)
  }
}

// ---------------------------------------------------------------------------
// Skill
// ---------------------------------------------------------------------------

struct Skill {
  name     string
  desc     string
  usage    Usage
  executor fn (args map[string]string) string @[required]
}

pub fn (skill Skill) help() string {
  return '${skill.usage.help}\n### Desc:\n - ${skill.desc}'
}

// ---------------------------------------------------------------------------
// Skills collection
// ---------------------------------------------------------------------------

pub struct Skills {
pub mut:
  skills []Skill
  count  int
}

// Register a new skill. Returns (false, reason) if name already taken.
pub fn (mut skills Skills) new_skill(
  name     string,
  desc     string,
  args     []string,
  executor fn (args map[string]string) string,
) (bool, string) {
  for x in skills.skills {
    if x.name == name {
      return false, "Skill '${name}' already registered."
    }
  }
  skills.skills << Skill{
    name:     name
    desc:     desc
    usage:    usage_build(name, args)
    executor: executor
  }
  skills.count++
  return true, ''
}

// ---------------------------------------------------------------------------
// System-prompt formatting
// ---------------------------------------------------------------------------

fn format_rules(opt string) string {
  match opt.to_lower() {
    'tool_usage' {
      return '\n## Tool Use — STRICT FORMAT' +
        '\nAlways use this exact XML format when calling a tool:' +
        '\n<tool_call name="TOOL_NAME">' +
        '\n  arg_name = value' +
        '\n  another_arg = another_value' +
        '\n</tool_call>' +
        '\n- Multiple <tool_call> blocks are allowed in one reply.' +
        '\n- One argument per line, key = value.' +
        '\n- Do NOT wrap the block in markdown fences.'
    }
    'tool_call_guidelines' {
      return '\n## Guidelines' +
        '\n1. Emit <tool_call> blocks inline when a tool is needed.' +
        '\n2. Wait for <tool_result> before continuing.' +
        '\n3. Only call tools that are necessary to answer the request.'
    }
    'reasoning' {
      return '\n## Reasoning' +
        '\n- Think step-by-step before acting.' +
        '\n- Reflect on tool results before the next action.' +
        '\n- Try alternative tools or arguments on failure.'
    }
    'output_fmt' {
      return '\n## Output Format' +
        '\n- Be concise and direct.' +
        '\n- Use markdown where it improves readability.'
    }
    else {
      return ''
    }
  }
}

// fmt_skills_and_guidelines returns the skills block appended to a system prompt.
pub fn (skills Skills) fmt_skills_and_guidelines() string {
  mut sb := strings.new_builder(2048)

  sb.write_string(format_rules('tool_call_guidelines'))
  sb.write_string('\n\n# Available Skills\n')

  for i, s in skills.skills {
    sb.write_string('${i + 1}. **${s.name}** — ${s.desc}\n')
  }

  for s in skills.skills {
    sb.write_string('\n\n## Skill: ${s.name}\n')
    sb.write_string(s.help())
  }

  sb.write_string('\n')
  sb.write_string(format_rules('tool_usage'))
  sb.write_string('\n')
  sb.write_string(format_rules('output_fmt'))
  return sb.str()
}

// ---------------------------------------------------------------------------
// Parser types
// ---------------------------------------------------------------------------

pub struct ToolCall {
pub mut:
  name string
  args map[string]string
}

pub struct Parser {
pub mut:
  tool_calls []ToolCall
  text       []string // non-tool lines
  raw        string
}

// fmt_parsed returns a human-readable summary of what was parsed.
pub fn (parser Parser) fmt_parsed() string {
  mut sb := strings.new_builder(256)
  sb.write_string('=== Parsed ===\n')
  if parser.text.len > 0 {
    sb.write_string('Text lines: ${parser.text.len}\n')
  }
  for tc in parser.tool_calls {
    sb.write_string('Tool: ${tc.name}\n')
    for k, v in tc.args {
      sb.write_string('  ${k} = ${v}\n')
    }
  }
  return sb.str()
}

// plain_text joins all non-tool lines into a single string.
pub fn (parser Parser) plain_text() string {
  return parser.text.join('\n').trim_space()
}

// ---------------------------------------------------------------------------
// parse  — extract <tool_call> blocks + remaining text
// ---------------------------------------------------------------------------

pub fn (skills Skills) parse(message string) Parser {
  mut parser := Parser{raw: message}
  lines := message.split('\n')
  mut i := 0

  for i < lines.len {
    line := lines[i].trim_space()

    if line.starts_with('<tool_call') && line.contains('name=') {
      // Extract tool name
      name_start := (line.index('name="') or { -1 }) + 6
      name_end   := if name_start > 5 {
        line.index_after('"', name_start) or { line.len }
      } else {
        -1
      }

      tool_name := if name_start > 5 && name_end > name_start {
        line[name_start..name_end]
      } else {
        ''
      }

      mut call := ToolCall{name: tool_name}
      i++

      for i < lines.len {
        curr := lines[i].trim_space()
        if curr == '</tool_call>' {
          i++
          break
        }
        // Parse key = value (value may itself contain '=')
        eq_idx := curr.index('=') or { -1 }
        if eq_idx > 0 {
          key   := curr[..eq_idx].trim_space()
          value := curr[eq_idx + 1..].trim_space()
          if key != '' {
            call.args[key] = value
          }
        }
        i++
      }

      if tool_name != '' {
        parser.tool_calls << call
      }
      continue
    }

    // Skip closing tags that appear without a matching open (shouldn't happen, but be safe)
    if !line.starts_with('</tool_call>') && line != '' {
      parser.text << line
    }
    i++
  }

  return parser
}

// ---------------------------------------------------------------------------
// execute_tool — run a single ToolCall
// ---------------------------------------------------------------------------

pub fn (skills Skills) execute_tool(call ToolCall) string {
  for skill in skills.skills {
    if skill.name == call.name {
      // Validate required args
      mut missing := []string{}
      for arg in skill.usage.args {
        if arg.name !in call.args {
          missing << arg.name
        }
      }
      if missing.len > 0 {
        return "Error: skill '${call.name}' is missing required args: ${missing.join(', ')}"
      }
      return skill.executor(call.args)
    }
  }
  available := skills.skills.map(it.name).join(', ')
  return "Error: skill '${call.name}' not found. Available: ${available}"
}

// ---------------------------------------------------------------------------
// execute_all — run every ToolCall in a Parser and return joined results
// ---------------------------------------------------------------------------

pub fn (skills Skills) execute_all(parser Parser) string {
  if parser.tool_calls.len == 0 {
    return ''
  }
  mut sb := strings.new_builder(512)
  for tc in parser.tool_calls {
    result := skills.execute_tool(tc)
    sb.write_string('<tool_result name="${tc.name}">\n${result}\n</tool_result>\n')
  }
  return sb.str().trim_space()
}