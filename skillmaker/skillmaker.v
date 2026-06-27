module main

import strings

struct Arg {
  pub mut:
  name  string
  dtype string
  value string
}

struct Usage {
  args       []Arg
  args_count int
  help       string
}

fn help_build(name string, args []Arg) string {
  mut sb := strings.new_builder(256)
  sb.write_string('<tool_call name="${name}">\n')
  for x in args {
    sb.write_string('  ${x.name} = VALUE_OF_TYPE(${x.dtype})_HERE\n')
  }
  sb.write_string('</tool_call>')
  return sb.str()
}

fn usage_build(name string, args []string) Usage {
  mut arguments := []Arg{}
  for x in args {
    mut my_arg := Arg{}
    ps := x.split(':')
    if ps.len == 2 {
      my_arg.name = ps[0]
      my_arg.dtype = ps[1]
    } else {
      my_arg.name = x
      my_arg.dtype = 'any'
    }
    arguments << my_arg
  }
  return Usage{
    args:       arguments
    args_count: arguments.len
    help:       help_build(name, arguments)
  }
}

struct Skill {
  name     string
  desc     string
  usage    Usage
  executor fn (args map[string]string) string @[required]
}

pub fn (skill Skill) help() string {
  mut sb := strings.new_builder(512)
  sb.write_string(skill.usage.help)
  sb.write_string('\n### Desc:\n - ${skill.desc}')
  return sb.str()
}

struct Skills {
  pub mut:
  skills []Skill
  count  int
}

fn (mut skills Skills) new_skill(name string, desc string, args []string, executor fn (args map[string]string) string) (bool, string) {
  for x in skills.skills {
    if x.name == name {
      return false, 'A skill with same name: ${name}, already exists.'
    }
  }
  new_skill := Skill{
    name:     name
    desc:     desc
    usage:    usage_build(name, args)
    executor: executor
  }
  skills.skills << new_skill
  skills.count++
  return true, ''
}

fn format_rules(opti string) string {
  opt := opti.to_lower()
  match opt {
    'tool_usage' {
      return '\n## Help for skill/tool usage: Tool Use -- STRICT RULES' +
        '\nYou MUST use this exact format:' +
        '\n<tool_call name="TOOL_NAME">' +
        '\n  arg_name = value' +
        '\n  another_arg = another_value' +
        '\n</tool_call>' +
        '\n- Multiple <tool_call> blocks are supported.' +
        '\n- Arguments are key = value lines (one per line).'
    }
    'tool_call_guidelines' {
      return '\n## Guidelines:' +
        '\n1. Emit <tool_call> blocks directly when needed.' +
        '\n2. Wait for results before next round.' +
        '\n3. Only use tools when necessary.'
    }
    'reasoning' {
      return '\n## Reasoning' +
        '\n- Think step-by-step.' +
        '\n- Reflect on tool results.' +
        '\n- Try alternatives on failure.'
    }
    'output_fmt' {
      return '\n## Output' +
        '\n- Be concise and clear.' +
        '\n- Use markdown for readability.'
    }
    else {
      return ''
    }
  }
}

fn (skills Skills) fmt_skills_and_guidelines() string {
  mut sb := strings.new_builder(2048)
  sb.write_string(format_rules('tool_call_guidelines'))
  sb.write_string('\n\n# All Skills:')

  for i, skilli in skills.skills {
    sb.write_string('\n${i + 1}: ${skilli.name} - ${skilli.desc}')
  }

  for skilli in skills.skills {
    sb.write_string('\n\n## skill: ${skilli.name}')
    sb.write_string('\n${skilli.help()}')
  }

  sb.write_string(format_rules('tool_usage'))
  sb.write_string(format_rules('output_fmt'))
  return sb.str()
}

struct ToolCall {
  pub mut:
  name string
  args map[string]string
}

struct Parser {
  pub mut:
  tool_calls []ToolCall
  text       []string
}

fn (skills Skills) parse(message string) Parser {
  mut parser := Parser{}
  lines := message.split('\n')
  mut i := 0

  for i < lines.len {
    line := lines[i].trim_space()
    if line.starts_with('<tool_call name=') {
      // Robust name extraction
      name_start := line.index('name="') or { -1 } + 6
      name_end := if name_start > 5 { line.index_after('"', name_start) or { line.len } } else { -1 }
      tool_name := if name_start > 5 && name_end > name_start { line[name_start..name_end] } else { '' }

      mut call := ToolCall{
        name: tool_name
        args: map[string]string{}
      }

      i++
      for i < lines.len {
        curr := lines[i].trim_space()
        if curr == '</tool_call>' {
          i++
          break
        }
        if curr.contains('=') {
          eq_idx := curr.index('=') or { -1 }
          if eq_idx > 0 {
            key := curr[..eq_idx].trim_space()
            value := curr[eq_idx + 1..].trim_space()
            if key != '' {
              call.args[key] = value
            }
          }
        }
        i++
      }
      if tool_name != '' {
        parser.tool_calls << call
      }
      continue
    } else if line != '' && !line.starts_with('</tool_call>') {
      parser.text << line
    }
    i++
  }
  return parser
}

fn (skills Skills) execute_tool(call ToolCall) string {
  for skill in skills.skills {
    if skill.name == call.name {
      return skill.executor(call.args)
    }
  }
  return 'Error: Skill "${call.name}" not found.'
}

fn main() {
  mut skill_list := Skills{}

  skill_list.new_skill('bash', 'Used to run bash commands.', ['command:string', 'timeout:milliseconds'],
    fn (args map[string]string) string {
      cmd := args['command'] or { 'echo "no command"' }
      timeout := args['timeout'] or { '30000' }
      return 'Bash executed: ${cmd} (timeout=${timeout}ms)'
    })

  skill_list.new_skill('weather', 'Gets weather for a city.', ['city:string', 'units:string'],
    fn (args map[string]string) string {
      city := args['city'] or { 'Unknown' }
      units := args['units'] or { 'metric' }
      return 'Weather for ${city}: 24°C, ${units}'
    })

  //println('=== Skills & Guidelines ===')
  //println(skill_list.fmt_skills_and_guidelines())

  test_input := '
Some normal text before tools.

<tool_call name="bash">
command = ls -la
timeout = 5000
</tool_call>

<tool_call name="weather">
city = Tokyo
units = metric
</tool_call>

More text after.
'

  println(test_input)
  parsed := skill_list.parse(test_input)

  println('\n=== Parsed ===')
  for tc in parsed.tool_calls {
    println('Tool: ${tc.name}')
    for k, v in tc.args {
      println('  ${k} = ${v}')
    }
  }

  println('\n=== Execution Results ===')
  for tc in parsed.tool_calls {
    result := skill_list.execute_tool(tc)
    println('→ ${tc.name}: ${result}')
  }
}