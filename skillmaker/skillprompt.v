module main

fn help_build(name string, args []Arg) string {
  mut help := "<tool_call> {\"name\":\"${name}\",\"args\":{"
  for x in args {
    mut arg_name := x.name
    mut arg_dtype := x.dtype
    help = "${help} \"${arg_name}\":\"VALUE_OF_TYPE(${arg_dtype})_HERE\""
  }
  help = "${help}}} </tool_call>"
  return help
}

struct Arg {
  pub mut:
    name string
    dtype string
}

fn usage_build(name string, args []string) Usage {
  mut arguments := []Arg{}
  for x in args {
    mut my_arg := Arg{}
    ps := x.split(":")
    if ps.len > 1 && ps.len < 3 {
      my_arg.name = x.split(":")[0]
      my_arg.dtype = x.split(":")[1]
    } else {
      my_arg.name = x.split(":")[0]
      my_arg.dtype = "any"
    }
    arguments << my_arg
  }

  return Usage{
    args: arguments,
    args_count: arguments.len
    help: help_build(name, arguments)
  }
}

struct Usage {
  args []Arg
  args_count int
  help string
}


fn format_rules(opti string) string {
  mut opt := opti.to_lower()
  if opt == "tool_usage" {
    mut rule := ""
    rule = "${rule} \n## Help for skill/tool usage: Tool Use -- STRICT RULES"
    rule = "${rule} \nYou MUST use the DSML (Domain Specific Markup Language) format to call tools. This is the ONLY way to invoke tools. Never describe a tool call in prose -- emit it directly."
    rule = "${rule} \n- every arg must be covered with perfect/valid (\")-these things."
    rule = "${rule} \n  example: short format: short format (preferred): <tool_call name=\"web_search\" query=\"vulnerabilities 2026\" /> "
    rule = "${rule} \n  big example: JSON format (if you need complex nested args): <tool_call> {\"name\": \"$TOOL_NAME\", \"args\": {\"$ARG_NAME\": \"$ARG_VALUE\"}} </tool_call> "
    //rule = "${rule} \n  the middle-man parser will look for: example: `$SKILL_HELP$` "
    rule = "${rule} \n- if your format is wrong, then you will recieve a syntax error."
    // dont call it here: rule = "${rule} \n${format_rules("tool_call_guidelines")}"
    return rule
  } else if opt == "tool_call_guidelines" {
    mut rule := ""
    rule = "${rule} \n## Guidelines:"
    rule = "${rule} \n1. If you need a tool, emit a <tool_call> block immediately -- no preamble, no explanation, no examples."
    // disable parrallel tool calling for now: will enable in deep research mode: rule = "${rule} \n2. You may call multiple tools in parallel by emitting multiple <tool_call> blocks."
    rule = "${rule} \n2. Wait for all results before the next tool round."
    // disable parrallel: rule = "${rule} \n4. Prefer parallel calls when tasks are independent."
    rule = "${rule} \n3. only ${format_rules("number_of_tool_calls")} skills request per message."
    rule = "${rule} \n   do not write more skill/tool calls more then that."
    rule = "${rule} \n4. Violations will be rejected: If you describe a tool call instead of emitting it, the system will not execute it and your response will be ignored."
    rule = "${rule} \n5. Only use tools when necessary: If you can answer from existing information or common knowledge, just answer directly -- no tool call needed. Tools are for fetching external data, executing code, or taking actions, not for simple questions."
    return rule
  } else if opt == "number_of_tool_calls" {
    return "1" // max num of tool calls per message, can change for deep-research-mode.
  } else if opt == "reasoning" {
    mut rule := ""
    rule = "${rule} \n## Reasoning"
    rule = "${rule} \n- Think step-by-step before calling tools."
    rule = "${rule} \n- After receiving tool results, reflect on them before proceeding."
    rule = "${rule} \n- If a tool fails, try an alternative approach."
    rule = "${rule} \n- When you have enough information, give a clear, direct final answer."
    return rule
  }

  return ""
}


struct Skill {
  name string
  desc string
  usage Usage // usage.args[x]/help
}

fn (skill Skill) help() string {
  mut help := skill.usage.help
  help = "${help} \n### Desc: \n - ${skill.desc}"
  //help = "${help} \n ${format_rules("tool_usage")}".replace("$SKILL_HELP$",skill.usage.help)
  return help
}

struct Skills {
  pub mut:
    skills []Skill // skills[x]
    count int
}

fn (mut skills Skills) new_skill(name string, desc string, args []string) (bool, string) {
  for x in skills.skills {
    if x.name == name {
      return false, "A skill with same name: '${name}', already exists."
    }
  }

  new_skill := Skill{
    name: name,
    desc: desc
    usage: usage_build(name, args)
  }

  skills.skills << new_skill
  skills.count = skills.count + 1
  return true, ""
}

fn (skills Skills) fmt_skills() string {
  mut skills_help := ""
  skills_help = "${skills_help} \n${format_rules("tool_call_guidelines")}\n\n# All Skills:"
  for x in 0..skills.skills.len {
      skilli := skills.skills[x]
      skills_help = "${skills_help} \n${x+1}: ${skilli.name} - ${skilli.desc}"
  }
  skills_help = "${skills_help} \n"
  for skilli in skills.skills {
      skills_help = "${skills_help} \n\n## skill: ${skilli.name}"
      skills_help = "${skills_help} \n${skilli.help()}"
  }
  skills_help = "${skills_help}} \n${format_rules("tool_usage")}"

  return skills_help
}

fn main() {
  mut skill_list := Skills{}
  skill_list.new_skill("bash","Used to run bash commands.","command:string timeout:milliseconds".split(" "))
  skill_list.new_skill("python3","Used to run python language version 3.14 code, in a sandbox.","code:string timeout:milliseconds".split(" "))
  skill_list.new_skill("web_search","Used to search web, and get links to matching results.","url:string max_links:int timeout:milliseconds".split(" "))
  skill_list.new_skill("web_get","Used to `get` the contents of a url","url:string max_words:int timeout:milliseconds".split(" "))

  // test: (should fail) duplicate name.
  // ok, err := skill_list.new_skill("bash","command timeout".split(" "))
  // if !ok {
  //   println(err)
  // }

  // test: println("Skill 0: ${skill_list.skills[0]}")
  // test: println("Help for SKill 0: \n${skill_list.skills[0].help()}")

  println(skill_list.fmt_skills())
}