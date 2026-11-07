# Last 5 records: timestamp, type, content block types.
# Its last timestamp is the step marker S for the other filters.
[inputs | select(.timestamp)] | .[-5:][]
| [.timestamp, .type,
   (.message.content | if type == "array" then map(.type) | join(",") else type end)]
| @tsv
