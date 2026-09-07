# Render an acpx --format json stream (raw ACP JSON-RPC) as readable terminal
# output. One renderer serves every peer: the schema belongs to the Agent Client
# Protocol, not to whichever harness is on the far end.
def dim: "\u001b[2m" + . + "\u001b[0m";
def cyan: "\u001b[36m" + . + "\u001b[0m";
def green: "\u001b[32m" + . + "\u001b[0m";
def red: "\u001b[31m" + . + "\u001b[0m";
def oneline: (. // "") | tostring | gsub("\\s+"; " ") | .[0:160];

if type != "object" then
  empty
elif .method == "session/update" then
  (.params.update // {}) as $u
  | ($u.sessionUpdate // "") as $kind
  | if $kind == "agent_message_chunk" then
      ($u.content.text // "")
    elif $kind == "agent_thought_chunk" then
      (($u.content.text // "") | dim)
    elif $kind == "tool_call" then
      "\n" + (("* " + ($u.kind // "tool")) | cyan) + " " + (($u.title | oneline) | dim) + "\n"
    elif $kind == "tool_call_update" then
      if ($u.status // "") == "failed" then
        (("  ! " + (($u.rawOutput.formatted_output // $u.status) | oneline)) | red) + "\n"
      else
        empty
      end
    else
      empty
    end
elif ((.result | type) == "object") and (.result.stopReason != null) then
  "\n" + (("[done] " + .result.stopReason) | green) + "\n"
elif ((.error | type) == "object") and (.error.message != null) then
  "\n" + (("[error] " + (.error.message | oneline)) | red) + "\n"
else
  empty
end
