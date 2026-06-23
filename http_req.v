module main

import net.http
import x.json2 // life savior..

struct OllamaRequest {
	model   string
	prompt  string
	stream  bool
 think   bool // used to enable think/othink mode, true=think, false=nothink
}

struct OllamaResponse {
	model     string
	response  string
	done      bool
}

fn main() { // TODO: Convert it into a lib. (soon)
	data := OllamaRequest{
		model:  "huihui_ai/qwen2.5-coder-abliterate:0.5b"
		prompt: "Why is the sky blue? Answer briefly."
		stream: false
	}

	json_data := json2.encode(data)

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
		return
	}

	result := json2.decode[OllamaResponse](resp.body) or {
		println("json decode operation failed: ${err}")
		return
	}

	println("status: ${resp.status_code}")
	println("model: ${result.model}")
	println("response: ${result.response}")
}


// YAY IT WORKS..
// status: 200
// model: huihui_ai/qwen2.5-coder-abliterate:0.5b
// response: The sky is blue because of.... (LOTS OF TEXT)