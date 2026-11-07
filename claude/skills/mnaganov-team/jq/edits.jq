# Files edited with Edit/Write/NotebookEdit since $s, deduplicated.
[inputs | select((.timestamp // "") >= $s and .type == "assistant")
 | .message.content | arrays | .[]
 | select(.type == "tool_use" and (.name | test("^(Edit|Write|NotebookEdit)$")))
 | .input.file_path // .input.notebook_path]
| unique | .[]
