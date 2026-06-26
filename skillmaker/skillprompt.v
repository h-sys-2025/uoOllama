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
    rule = "${rule} \n  the middle-man parser will look for: example: `$SKILL_HELP$` "
    rule = "${rule} \n- if your format is wrong, then you will recieve a syntax error."
    rule = "${rule} \n${format_rules("many_tools_per_message")}"
    return rule
  } else if opt == "many_tools_per_message" {
    mut rule := ""
    rule = "${rule} \n## Guidelines:"
    rule = "${rule} \n- only ${format_rules("number_of_tool_calls")} skills request per message."
    rule = "${rule} \n  do not write more skill/tool calls more then that."
    return rule
  } else if opt == "number_of_tool_calls" {
    return "1" // max num of tool calls per message, can change for deep-research-mode.
  }

  return ""
}


struct Skill {
  name string
  usage Usage // usage.args[x]/help
}

fn (skill Skill) help() string {
  mut help := skill.usage.help
  help = "${help} \n ${format_rules("tool_usage")}".replace("$SKILL_HELP$",skill.usage.help)
  return help
}

struct Skills {
  pub mut:
    skills []Skill // skills[x]
    count int
}

fn (mut skills Skills) new_skill(name string, args []string) (bool, string) {
  for x in skills.skills {
    if x.name == name {
      return false, "A skill with same name: '${name}', already exists."
    }
  }

  new_skill := Skill{
    name: name,
    usage: usage_build(name, args)
  }

  skills.skills << new_skill
  skills.count = skills.count + 1
  return true, ""
}

fn main() {
  mut skill_list := Skills{}
  skill_list.new_skill("bash","command:string timeout:milliseconds".split(" "))

  // test: (should fail) duplicate name.
  // ok, err := skill_list.new_skill("bash","command timeout".split(" "))
  // if !ok {
  //   println(err)
  // }

  println("Skill 0: ${skill_list.skills[0]}")
  println("Help for SKill 0: \n${skill_list.skills[0].help()}")
}