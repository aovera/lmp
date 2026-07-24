package.path = "../?.lua;../?/init.lua;" .. package.path
local bigint = require("bigint")

-- Generates a random numeric string of a specified length
local function generate_large_string(length)
    local t = {}
    table.insert(t, tostring(math.random(1, 9))) -- First digit cannot be 0
    for i = 2, length do
        table.insert(t, tostring(math.random(0, 9)))
    end
    return table.concat(t)
end

print("=== BIGINT ASYMPTOTIC TIME COMPLEXITY ANALYSIS ===\n")

local sizes = {500, 1000, 2000, 4000, 8000, 16000, 32000, 64000, 128000}
local prev_time = nil

for _, size in ipairs(sizes) do
    local s1 = generate_large_string(size)
    local s2 = generate_large_string(size)
    
    local b1 = bigint.new(s1)
    local b2 = bigint.new(s2)
    
    -- Manually trigger Garbage Collector (GC) before testing to prevent timing anomalies
    collectgarbage("collect")
    
    local start_time = os.clock()
    
    -- Running multiple operations per test to obtain measurable CPU time
    -- If the library is too slow, you can reduce the loop count to 1.
    for i = 1, 10 do
        local _ = b1 * b2
    end
    
    local end_time = os.clock()
    local elapsed = end_time - start_time
    
    local growth_factor = 0
    if prev_time and prev_time > 0 then
        growth_factor = elapsed / prev_time
    end
    
    if prev_time == nil then
        print(string.format("Digits: %-7d | Time: %.4f sec", size, elapsed))
    else
        print(string.format("Digits: %-7d | Time: %.4f sec | Growth Factor: %.2fx", size, elapsed, growth_factor))
    end
    
    prev_time = elapsed
end
