# Easy to use (and un-official) lib to use selfhosted ollama models, in v..
- Very simple lib:
- This is a MICRO-LIB, onsists of very few functions, and can be used in small projects, and nothing more.

![0.2](https://img.shields.io/badge/version-0.2.5-white?style=flat)
![GitHub](https://img.shields.io/badge/license-MIT-blue?style=flat)
![vlang](http://img.shields.io/badge/V-0.5+-%236d8fc5?style=flat)

## Installazation:
```v
v install h-sys-2025.uoOllama
```

## Example:
```v
module main

// v install h-sys-2025.uoOllama
import h_sys_2025.uoollama.uoollama { OllamaRequest }

fn main() {
    // basic req:
    mut req := OllamaRequest{
        model:  "huihui_ai/qwen2.5-coder-abliterate:0.5b"
        prompt: "Why is the sky blue? Answer briefly."
        stream: false
    }

    // test: ok, errmsg := req.set_model("abcd")

    // test:
    // if !ok {
    //     println(errmsg)
    //     return
    // }

    // test:
    resp := req.completion()
    resp.print()
    //println(req.model)
}
```

### imports:
```v
import net.http
import x.json2
```

### Structures:
```v
// basic request structure.
struct OllamaRequest {
    mut: model   string
    prompt  string
    stream  bool
    think   bool // used to enable think/othink mode, true=think, false=nothink
}

// responce structure, contains completion (answers and debug info from the AI.)
struct OllamaResponse {
    model     string
    response  string
    done      bool
}

// An ollama model structure
struct OllamaModel {
    name       string
    size       i64
    digest     string
    modified_at string
}

// List of ALL ollama models (currently avalable on your system.) (function list_ollama_models() returns it.)
struct OllamaModels {
    models []OllamaModel
}

```

### Functions:
```v
// completion, get answers from AI.
fn (req OllamaRequest) completion() OllamaResponse

// list all avalable models.
fn list_ollama_models() (OllamaModels, string)

// use anathor model for same request.
fn (mut req OllamaRequest) set_model(model_name string) (bool, string)

// prompt the AI with different prompt.
pub fn (mut req OllamaRequest) prompt_complete(prompt string) OllamaResponse

// print responce.
fn (resp OllamaResponse) print()
```

## Example:
```v
fn main() {
    // basic req:
    mut req := OllamaRequest{
        model:  "huihui_ai/qwen2.5-coder-abliterate:0.5b"
        prompt: "Why is the sky blue? Answer briefly."
        stream: false
    }

    // test: ok, errmsg := req.set_model("abcd")

    // test:
    if !ok {
        println(errmsg)
        return
    }

    // test:
    resp := req.completion()
    resp.print()
    println(req.model)
}

// YAY IT WORKS..
// status: 200
// model: huihui_ai/qwen2.5-coder-abliterate:0.5b
// response: The sky is blue because of.... (LOTS OF TEXT)
```