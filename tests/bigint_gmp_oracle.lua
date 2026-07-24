package.path = "../?.lua;../?/init.lua;" .. package.path
package.cpath = "../build/?.so;../build/?.dylib;../build/?.dll;" .. package.cpath

local bigint = require("bigint")
local gmporacle = require("gmporacle")

math.randomseed(os.time())

-- Generates a random numeric string with the specified number of digits
local function generate_random_number_string(length)
    local t = {}
    -- The first digit cannot be 0
    table.insert(t, tostring(math.random(1, 9)))
    for i = 2, length do
        table.insert(t, tostring(math.random(0, 9)))
    end
    return table.concat(t)
end

local function assert_oracle(op_name, lua_res, gmp_res, val1, val2)
    local str_lua = tostring(lua_res)
    local str_gmp = tostring(gmp_res)
    --print("gmp: " .. str_gmp, "lmp: " .. str_lua)
    if str_lua ~= str_gmp then
        error(string.format(
            "[%s] MISMATCH DETECTED!\nNumber 1: %s\nNumber 2: %s\nYour Code : %s\nGMP Result: %s",
            op_name, val1, val2, str_lua, str_gmp
        ))
    end
end

print("=== BIGINT GMP ORACLE TEST ===\n")

local ITERATIONS = 1000
local DIGITS = 1100

for i = 1, ITERATIONS do
    local s1 = generate_random_number_string(DIGITS)
    local s2 = generate_random_number_string(DIGITS - 20) -- Testing numbers of different lengths

    local b1 = bigint.new(s1)
    local b2 = bigint.new(s2)

    -- 1. Addition
    assert_oracle("ADDITION", b1 + b2, gmporacle.add(s1, s2), s1, s2)

    -- 2. Subtraction
    assert_oracle("SUBTRACTION", b1 - b2, gmporacle.sub(s1, s2), s1, s2)
    assert_oracle("SUBTRACTION (Negative)", b2 - b1, gmporacle.sub(s2, s1), s2, s1)

    -- 3. Multiplication
    assert_oracle("MULTIPLICATION", b1 * b2, gmporacle.mul(s1, s2), s1, s2)

    -- 4. Division and Modulo
    assert_oracle("DIVISION", b1 / b2, gmporacle.div(s1, s2), s1, s2)
    assert_oracle("MODULO", b1 % b2, gmporacle.mod(s1, s2), s1, s2)
    
    -- 5. Exponentiation (Exponent is capped)
    local exp = math.random(2, 50)  
    local s_exp = tostring(exp)
    local b_exp = bigint.new(s_exp)
    -- Testing exponentiation with s2 as the base and exp as the exponent
    assert_oracle("EXPONENTIATION", b2 ^ b_exp, gmporacle.pow(s2, exp), s2, s_exp)
    
    if i % 100 == 0 then
        print(string.format("%d operations verified against GMP reference.", i))
    end
end

print("\n[PASSED] All operations are in absolute agreement with GMP.")
