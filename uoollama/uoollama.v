module uoollama

import net.http
import x.json2
import time

import h_sys_2025.uoollama.skillmaker { Skills }

pub fn gen_sys_prompt(skills Skills, bio string) string {
  mut sys_prompt := bio
  sys_prompt = "${sys_prompt} \n${skills.fmt_skills_and_guidelines()}"
  return sys_prompt
}

pub struct OllamaRequest {
    pub mut:
        model   string
        prompt  string
        stream  bool
        think   bool // used to enable think/othink mode, true=think, false=nothink
}

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
  		    println("json decode operation failed: ${err}")
      		return OllamaResponse{}
   	}

    end_time := time.now().unix()
    duration := (end_time - start_time)
   	result.time_taken = duration
    return result
}

pub struct OllamaModel {
    name       string
    size       i64
    digest     string
    modified_at string
}

pub struct OllamaModels {
    models []OllamaModel
}

pub fn list_ollama_models() (OllamaModels, string) {
    resp := http.get("http://localhost:11434/api/tags") or {
        return OllamaModels{}, "some error"
    }

   	if resp.status_code != 200 {
      		return OllamaModels{}, "Error: Received status code ${resp.status_code}"
   	}

   	data := json2.decode[OllamaModels](resp.body) or {
      		return OllamaModels{}, "Error parsing JSON: ${err}"
   	}

    return data, ""
}

pub fn (mut req OllamaRequest) set_model(model_name string) (bool, string) {
    models_, err := list_ollama_models()
    if err != "" {
        return false, err
    } else {
        for x in 0..models_.models.len {
            model := models_.models[x]
            if model.name == model_name {
                req.model = model_name
                return true, ""
            } else {
                return false, "Model: ${model_name} does not exist! use list_ollama_models() to get all avalable ones."
            }
        }
    }

    return true, ""
}

pub fn (mut req OllamaRequest) prompt_complete(prompt string) OllamaResponse {
    req.prompt = prompt
    resp:= req.completion()
    return resp
}

pub struct OllamaResponse {
    model     string
    response  string
    pub mut: time_taken i64
}

pub fn (resp OllamaResponse) print() {
   	println("model: ${resp.model}")
   	println("time-taken: ${resp.time_taken} second(s)")
   	println("response: ${resp.response}")
    return
}

// fn main() {
    // basic req:
    // mut req := OllamaRequest{
    //     model:  "huihui_ai/qwen2.5-coder-abliterate:0.5b"
    //     prompt: "Why is the sky blue? Answer briefly."
    //     stream: false
    // }

    // test: ok, errmsg := req.set_model("abcd")

    // test:
    // if !ok {
    //     println(errmsg)
    //     return
    // }

    // test:
    // resp := req.completion()
    // resp.print()
    // println(req.model)
// }

// YAY IT WORKS..
// status: 200
// model: huihui_ai/qwen2.5-coder-abliterate:0.5b
// response: The sky is blue because of.... (LOTS OF TEXT)