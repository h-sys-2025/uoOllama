module main

fn help_build(name string, args []string) string {
  mut help := "<tool_call> {\"name\":\"${name}\",\"args\":{"
  for x in args {
    help = "${help} \"${x}\":\"VALUE_HERE\""
  }
  help = "${help}}} </tool_call>"
  return help
}

fn usage_build(name string, args []string) Usage {
  return Usage{
    args: args,
    args_count: args.len
    help: help_build(name, args)
  }
}

struct Usage {
  args []string
  args_count int
  help string
}


fn format_rules(opti string) string {
  mut opt := opti.to_lower()
  if opt == "tool_usage" {
    mut rule := ""
    rule = "${rule} \n## Help for skill/tool usage:"
    rule = "${rule} \n- every arg must be covered with perfect/valid (\")-these things."
    rule = "${rule} \n  example: <tool_call> {\"name\": \"$TOOL_NAME\", \"args\": {\"$ARG_NAME\": \"$ARG_VALUE\"}} </tool_call> "
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
  skill_list.new_skill("bash","command timeout".split(" "))

  // test: (should fail) duplicate name.
  // ok, err := skill_list.new_skill("bash","command timeout".split(" "))
  // if !ok {
  //   println(err)
  // }

  println("Skill 0: ${skill_list.skills[0]}")
  println("Help for SKill 0: \n${skill_list.skills[0].help()}")
}