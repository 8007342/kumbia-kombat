-- locate.lua grid.f32 loop.f32 lo hi: where the loop's tail sits in the grid, and the grid's own step there.
local function rd(p) local f = assert(io.open(p, "rb")); local s = f:read("a"); f:close(); return s, #s // 8 end
local gs, gn = rd(arg[1]); local ls, ln = rd(arg[2])
local function g(i) return string.unpack("<ff", gs, (i - 1) * 8 + 1) end
local function l(i) return string.unpack("<ff", ls, (i - 1) * 8 + 1) end
local K = 4000; local tl = {}
for k = 1, K do local a, b = l(ln - K + k); tl[k] = a + b end
local best, bs = -1, 0
for s = tonumber(arg[3]), tonumber(arg[4]) do -- loop sample i = grid sample s + i - 1
  local xy, xx, yy = 0, 0, 0
  for k = 1, K, 4 do local a, b = g(s + ln - K + k - 1); local x = a + b; local y = tl[k]; xy = xy + x * y; xx = xx + x * x; yy = yy + y * y end
  local c = xy / math.sqrt(xx * yy + 1e-30); if c > best then best, bs = c, s end end
local e = bs + ln - 1 -- grid index of the loop's last sample
local a1, b1 = g(e); local a2, b2 = g(e + 1); local la, lb = l(ln); local fa, fb = l(1)
local ga = 0; for k = 1, K do local a, b = g(e - K + k); local x, y = l(ln - K + k); ga = ga + (x + y) / ((a + b) ~= 0 and (a + b) or 1e-9) end
print(string.format("loop starts at grid %d (corr %.4f)\ngrid step across the loop end: %.4f (L %.4f->%.4f R %.4f->%.4f)\nloop wrap step: %.4f (L %.4f->%.4f R %.4f->%.4f)",
  bs, best, math.max(math.abs(a2 - a1), math.abs(b2 - b1)), a1, a2, b1, b2, math.max(math.abs(fa - la), math.abs(fb - lb)), la, fa, lb, fb))
local r = {} for k = 1, K do local a, b = g(e - K + k); local x, y = l(ln - K + k); if math.abs(a + b) > 0.05 then r[#r + 1] = (x + y) / (a + b) end end
table.sort(r); print(string.format("tail gain loop/grid median %.3f (%.2f dB)", r[#r // 2], 20 * math.log(r[#r // 2], 10)))
