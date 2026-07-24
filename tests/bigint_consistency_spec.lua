-- test_bigint.lua

package.path = "../?.lua;../?/init.lua;" .. package.path
package.cpath = "../build/?.so;../build/?.dylib;../build/?.dll;" .. package.cpath
local bigint = require("bigint")

-- Helper functions
local function run_test(name, test_func)
    local status, err = pcall(test_func)
    if status then
        print("[SUCCESS] " .. name)
    else
        print("[ERROR] " .. name .. " -> " .. tostring(err))
    end
end

local function assert_error(name, test_func)
    local status, _ = pcall(test_func)
    if not status then
        print("[SUCCESS] " .. name .. " (Error handled as expected)")
    else
        print("[ERROR] " .. name .. " -> Error expected, no handled.")
    end
end

print("=== BIGINT LIBRARY TEST ===\n")

-- Init and parsing tests
run_test("Init: Basic assingment", function()
    local a = bigint.new("123")
    local b = bigint.new("-456")
    assert(a == bigint.new("123"), "Error: Positive number creation")
    assert(b == bigint.new("-456"), "Error: Negative number creation")
end)

run_test("Init: Signless 0", function()
    local zero1 = bigint.new("0")
    local zero2 = bigint.new("-0")
    assert(zero1 == zero2, "-0 and 0 must be equal")
end)

run_test("Init: Leading Zero truncate", function()
    local a = bigint.new("0000123")
    assert(a == bigint.new("123"), "Leading zeros could not be truncated")
end)

-- Relational operators (<, <=, ==)
run_test("Relational operators: Equality and less than", function()
    local a = bigint.new("100")
    local b = bigint.new("100")
    local c = bigint.new("101")
    local d = bigint.new("-50")

    assert(a == b, "== error")
    assert(a <= b, "<= operator is incorrect in equality state")
    assert(a < c, "< error")
    assert(a <= c, "<= error")
    assert(d < a, "Negative must be less than positive")
end)

-- Sum and sub
run_test("Sum: Carry Transfer", function()
    local a = bigint.new("9999")
    local b = bigint.new("1")
    assert(a + b == bigint.new("10000"), "Carry transfer error in summary operation")
end)

run_test("Sub: Borrow", function()
    local a = bigint.new("10000")
    local b = bigint.new("1")
    assert(a - b == bigint.new("9999"), "Borrow error in substraction operation")
    assert(a - a == bigint.new("0"), "a - a must be equal to 0")
end)

run_test("Sum/Sub: Sign", function()
    local a = bigint.new("50")
    local b = bigint.new("-20")
    assert(a + b == bigint.new("30"), "Error in positive negative sum")
    assert(b - a == bigint.new("-70"), "Error in substraction positive from negative")
end)

-- Mult
run_test("Mult: Mult with 0 and 1", function()
    local a = bigint.new("987654321")
    local zero = bigint.new("0")
    local one = bigint.new("1")
    
    assert(a * zero == zero, "Error: mult with 0")
    assert(a * one == a, "Error: Mult with 1")
end)

run_test("Mult: Big numbers and signs", function()
    local a = bigint.new("99999")
    local b = bigint.new("-99999")
    -- 99999 * -99999 = -9999800001
    assert(a * b == bigint.new("-9999800001"), "Error in multiplication of big number with opposite signs")
end)

-- Div and mod
run_test("Div: Integer Division", function()
    local a = bigint.new("10")
    local b = bigint.new("3")
    assert(a / b == bigint.new("3"), "Integer division error")
end)

run_test("Div and mod: Euclid Completeness", function()
    local a = bigint.new("1234567")
    local b = bigint.new("89")
    local q = a / b
    local r = a % b
    -- a = q * b + r
    assert((q * b) + r == a, "Div and mod are inconsistent")
end)

assert_error("Div: Division by zero", function()
    local a = bigint.new("10")
    local zero = bigint.new("0")
    local _ = a / zero -- Error expected
end)

-- Power
run_test("Pow: Basic rules and 0^0", function()
    local base = bigint.new("2")
    local exp = bigint.new("10")
    local zero = bigint.new("0")
    local one = bigint.new("1")

    assert(base ^ exp == bigint.new("1024"), "Power operation error")
    assert(zero ^ zero == one, "0^0 expected 1 as answer not granted")
    assert(base ^ zero == one, "n^0 must be equal to 1")
    assert(zero ^ exp == zero, "Positive powers of 0 must be 0")
end)

assert_error("Power: Negative power not supported", function()
    local base = bigint.new("2")
    local neg_exp = bigint.new("-3")
    local _ = base ^ neg_exp -- Error expected here
end)

print("\n=== TEST COMPLETE ===")
