# Failed tool calls since $s: is_error results or nonzero exit codes.
inputs | select((.timestamp // "") >= $s and .type == "user")
| .timestamp as $t
| .message.content | arrays | .[] | select(.type == "tool_result")
| (.content | if type == "array" then map(.text? // "") | join("\n")
              else (. // "" | tostring) end) as $c
| select(.is_error == true or ($c | test("^Exit code [1-9]")))
| {t: $t, c: $c[0:500]}
