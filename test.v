// module main

// v install h-sys-2025.uoOllama
import h_sys_2025.uoollama { OllamaRequest }

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