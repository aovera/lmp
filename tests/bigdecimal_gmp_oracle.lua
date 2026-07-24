package.path = "../?.lua;../?/init.lua;" .. package.path
package.cpath = "../build/?.so;../build/?.dylib;../build/?.dll;" .. package.cpath

local bigdecimal = require("bigdecimal")
local gmpdec = require("gmpdec")

math.randomseed(os.time())

local function generate_random_digits(length)
    local t = {}
    table.insert(t, tostring(math.random(1, 9)))
    for i = 2, length do
        table.insert(t, tostring(math.random(0, 9)))
    end
    return table.concat(t)
end

local function assert_oracle(op_name, lua_res, gmp_res)
    local str_lua = tostring(lua_res)
    if str_lua ~= gmp_res then
        error(string.format(
            "[%s] MISMATCH!\nLua Result: %s\nGMP Result: %s",
            op_name, str_lua, gmp_res
        ))
    end
end

print("=== BIGDECIMAL HIGH-PRECISION GMP ORACLE TEST ===\n")

local ITERATIONS = 1000
local INT_DIGITS = 50
local PRECISION = 1000

for i = 1, ITERATIONS do
    local int_part1 = generate_random_digits(INT_DIGITS)
    local frac_part1 = generate_random_digits(PRECISION)
    local val_str1 = int_part1 .. "." .. frac_part1
    
    local int_part2 = generate_random_digits(INT_DIGITS - 10)
    local frac_part2 = generate_random_digits(PRECISION - 5)
    local val_str2 = int_part2 .. "." .. frac_part2

    local a = bigdecimal.new(val_str1, PRECISION)
    local b = bigdecimal.new(val_str2, PRECISION - 5)

    -- 1. Addition Test
    assert_oracle("ADDITION", a + b, gmpdec.add(int_part1 .. frac_part1, PRECISION, int_part2 .. frac_part2, PRECISION - 5))

    -- 2. Subtraction Test
    assert_oracle("SUBTRACTION", a - b, gmpdec.sub(int_part1 .. frac_part1, PRECISION, int_part2 .. frac_part2, PRECISION - 5))

    -- 3. Multiplication Test (Dynamic & High Precision)
    assert_oracle("MULTIPLICATION", a * b, gmpdec.mul(int_part1 .. frac_part1, PRECISION, int_part2 .. frac_part2, PRECISION - 5))

    -- 4. Custom Precision Division & Truncation Test (Dynamic)
    -- Target precision is fixed to test absolute truncation boundaries.
    local custom_prec = 2000  
    assert_oracle("DIVISION", bigdecimal.div(a, b, custom_prec), gmpdec.div(int_part1 .. frac_part1, PRECISION, int_part2 .. frac_part2, PRECISION - 5, custom_prec))

    if i % 200 == 0 then
        print(string.format("%d iterations verified with high precision.", i))
    end
end

print("\n[PASSED] BigDecimal library successfully passed all high-precision GMP tests.")
