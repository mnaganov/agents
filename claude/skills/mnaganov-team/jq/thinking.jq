# Reasoning since $s.
inputs | select((.timestamp // "") >= $s and .type == "assistant")
| .timestamp as $t
| .message.content | arrays | .[]
| select(.type == "thinking" and (.thinking // "") != "")
| "## \($t)\n\(.thinking[0:1500])"
