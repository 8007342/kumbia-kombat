-- .tillandsias/hooks/pre-push.lua
-- Project override of the embedded pre-push discipline template (order 1446-xqi6).
-- Same contract as the embedded copy; differs only in the refusal affordance:
-- a refusal echoes the seed's own why/remedy (messages.default_branch_denied
-- lives there) and ends with the project's branch-flow affordance.
local plan, host_kind, os_env = arg[1], arg[2] or "", arg[3] or ""
local function err(line) io.stderr:write(line, "\n") end
local function run(argv)
  local r = proc.run{ argv = argv }
  return r.code, r.stdout or "", r.stderr or ""
end
local function first_line(s) return (s:match("^[^\n]*")) or "" end
local function platform()
  if host_kind == "forge" then return "forge" end
  if os_env == "Windows_NT" then return "windows" end
  local _, out = run{ "uname", "-s" }
  local k = first_line(out)
  if k == "Darwin" then return "macos" end
  if k:match("^MINGW") or k:match("^MSYS") or k:match("^CYGWIN") then return "windows" end
  return "linux"
end
local _, show_out = run{ plan, "discipline", "show", "--json" }
local sok, d = pcall(json.parse, show_out)
if not sok or type(d) ~= "table" then
  err("`discipline show --json` gave no answer; a question the seed could not answer is not permission to push.")
  return "blocked:hook:pre-push:discipline-unanswered"
end
local refused = nil
for line in io.lines() do
  local remote_ref = line:match("^%S+%s+%S+%s+(%S+)")
  if remote_ref then
    local code, out = run{ plan, "discipline", "check-ref", remote_ref }
    local verdict = first_line(out)
    if not verdict:match("^[a-z]+:discipline") then
      err("`discipline check-ref " .. remote_ref .. "` gave no verdict (rc=" .. tostring(code) .. ").")
      return "blocked:hook:pre-push:discipline-unanswered"
    end
    local token = verdict:match("^refused:discipline:([%w%-]+):enforced")
    if token and not refused then
      refused = { ref = remote_ref, token = token, why = out }
    end
    local soft = verdict:match("^warn:discipline:(.+)$")
    if soft then
      err("warn: " .. remote_ref .. " — " .. soft)
      local remedy = out:match("\nremedy: ([^\n]*)")
      if remedy then err("  " .. remedy) end
    end
  end
end
if not refused then return "ok:hook:pre-push" end
local branch = refused.ref:gsub("^refs/heads/", "")
local _, target_out = run{ plan, "discipline", "target", "--platform", platform() }
local integration = first_line(target_out):match("^(%S+)") or "game"
for l in refused.why:gmatch("[^\n]+") do err(l) end
err("use work/ branches, then pull-request into the " .. integration
  .. " integration branch, then pull-requests into main.")
if refused.token == "default-branch-protected" then
  return "refused:hook:pre-push:default-branch-protected:enforced"
end
return "refused:hook:pre-push:" .. refused.token .. ":enforced"
