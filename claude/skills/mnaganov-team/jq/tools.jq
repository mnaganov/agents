# Tool calls since $s.
inputs | select((.timestamp // "") >= $s and .type == "assistant")
| .timestamp as $t
| .message.content | arrays | .[] | select(.type == "tool_use")
| {t: $t, name, a: (.input | tostring | .[0:300])}
