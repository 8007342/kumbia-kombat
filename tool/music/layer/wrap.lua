-- wrap.lua A.f32 [B.f32]: raw stereo float32 loops (48 kHz). For each: the step across the
-- wrap (last sample -> first) against the distribution of steps inside, and the sharpest
-- second difference in the last 50 ms. With B, the residual B-A by region.
local SR = 48000
local function load(path)
  local f = assert(io.open(path, "rb")); local s = f:read("a"); f:close()
  local n = #s // 8; local L, R = {}, {}
  local pos = 1
  for i = 1, n do L[i], R[i], pos = string.unpack("<ff", s, pos) end
  return L, R, n
end
local function stats(L, R, n, name)
  local steps = {}
  for i = 2, n do steps[#steps+1] = math.max(math.abs(L[i]-L[i-1]), math.abs(R[i]-R[i-1])) end
  local wrap = math.max(math.abs(L[1]-L[n]), math.abs(R[1]-R[n]))
  table.sort(steps)
  local rank = 0
  for i = #steps, 1, -1 do if steps[i] <= wrap then rank = i break end end
  local function q(p) return steps[math.max(1, math.floor(p * #steps))] end
  -- second difference, sharpest in the last 50 ms, the first 50 ms (across the wrap), and overall
  local function d2(i) -- i may wrap
    local function g(t, k) return t[(k - 1) % n + 1] end
    return math.max(math.abs(g(L,i)-2*g(L,i-1)+g(L,i-2)), math.abs(g(R,i)-2*g(R,i-1)+g(R,i-2)))
  end
  local function sharpest(a, b) local m, at = 0, a for i = a, b do local v = d2(i) if v > m then m, at = v, i end end return m, at end
  local tail, tailAt = sharpest(n - SR // 20, n)
  local head, headAt = sharpest(1, SR // 20)
  local all = sharpest(3, n)
  print(string.format("%s: n=%d wrapStep=%.5f (pct %.4f; p50 %.5f p99 %.5f p99.9 %.5f max %.5f)", name, n, wrap,
    rank / #steps * 100, q(0.5), q(0.99), q(0.999), steps[#steps]))
  print(string.format("  d2 sharpest: last50ms %.5f at -%.1f ms; first50ms(incl wrap) %.5f at %.1f ms; whole loop %.5f",
    tail, (n - tailAt) / SR * 1000, head, (headAt - 1) / SR * 1000, all))
end
local function resid(A1, A2, B1, B2, n, name)
  local function rms(a, b) local s = 0 for i = a, b do s = s + (B1[i]-A1[i])^2 + (B2[i]-A2[i])^2 end return math.sqrt(s / (2*(b-a+1))) end
  local function sig(a, b) local s = 0 for i = a, b do s = s + A1[i]^2 + A2[i]^2 end return math.sqrt(s / (2*(b-a+1))) end
  local w = SR // 25
  local function db(x) return 20 * math.log(math.max(x, 1e-12), 10) end
  local mx, at = 0, 1
  for i = 1, n do local v = math.max(math.abs(B1[i]-A1[i]), math.abs(B2[i]-A2[i])) if v > mx then mx, at = v, i end end
  print(string.format("  residual %s: whole %.1f dB rel signal; first40ms %.1f; last40ms %.1f; max |err| %.4f at %.3f s (-%.1f ms from end)",
    name, db(rms(1, n)) - db(sig(1, n)), db(rms(1, w)) - db(sig(1, w)), db(rms(n-w+1, n)) - db(sig(n-w+1, n)), mx, (at-1)/SR, (n-at)/SR*1000))
end
local A1, A2, n = load(arg[1]); stats(A1, A2, n, arg[1]:match("[^/]+/[^/]+$"))
if arg[2] then local B1, B2, m = load(arg[2]); assert(m == n, "length " .. m .. " vs " .. n); stats(B1, B2, m, "decoded"); resid(A1, A2, B1, B2, n, "decoded-f32") end
