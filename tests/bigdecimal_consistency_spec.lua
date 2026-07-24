-- test_bigdecimal.lua

package.path = "../?.lua;../?/init.lua;" .. package.path
package.cpath = "../build/?.so;../build/?.dylib;../build/?.dll;" .. package.cpath
local bigdecimal = require("bigdecimal")

local function run_test(name, test_func)
    local status, err = pcall(test_func)
    if status then
        print("[PASSED] " .. name)
    else
        print("[FAILED] " .. name .. " -> " .. tostring(err))
    end
end

print("=== BIGDECIMAL LIBRARY LOGICAL INTEGRITY TEST ===\n")

-- INITIALIZATION AND PRECISION MANAGEMENT
run_test("Initialization: Padding Missing Precision with Zeros", function()
    local a = bigdecimal.new("0.1", 5)
    -- Testing internal state via string conversion since equality operator normalizes scale
    -- (Assumes the library's __tostring metamethod reflects precision)
    assert(tostring(a) == "0.10000", "Missing precision is not being padded with zeros.")
end)

run_test("Initialization: Truncating Excess Precision", function()
    local a = bigdecimal.new("0.12345", 2)
    assert(tostring(a) == "0.12", "Excess precision is not being truncated properly.")
    
    local b = bigdecimal.new("0.999", 2)
    assert(tostring(b) == "0.99", "Incorrect rounding applied instead of truncation.")
end)

-- RELATIONAL OPERATORS (EQUAL & COMPARE)
run_test("Comparison: Scale Normalization", function()
    local a = bigdecimal.new("1.5", 1)
    local b = bigdecimal.new("1.500", 3)
    
    assert(a == b, "Values of equal magnitude with different precision are not considered equal.")
    assert(not (a < b), "Less-than operator erroneously triggered on equal numbers.")
end)

-- ADDITION AND SUBTRACTION (SCALE ALIGNMENT)
run_test("Addition/Subtraction: Preserving Maximum Precision", function()
    local a = bigdecimal.new("1.5", 1)
    local b = bigdecimal.new("2.03", 2)
    
    local c = a + b
    assert(c == bigdecimal.new("3.53", 2), "Addition result value calculated incorrectly.")
    -- Resulting precision for addition/subtraction must match max(prec_A, prec_B)
    assert(tostring(c) == "3.53", "Addition result precision does not follow max(prec_A, prec_B) rule.")
    
    local d = b - a
    assert(d == bigdecimal.new("0.53", 2), "Alignment error in subtraction operation.")
end)

-- MULTIPLICATION (PRECISION ACCUMULATION)
run_test("Multiplication: Summing Precisions (Prec_A + Prec_B)", function()
    local a = bigdecimal.new("1.2", 1)
    local b = bigdecimal.new("3.45", 2)
    
    local c = a * b
    -- 1.2 * 3.45 = 4.14 -> Since total precision is 1+2=3, output must be 4.140.
    assert(c == bigdecimal.new("4.14", 2), "Mathematical value of multiplication result is incorrect.")
    assert(tostring(c) == "4.140", "Multiplication precision sum rule (1+2=3) failed.")
end)

-- DIVISION AND TRUNCATION
run_test("Division: Default 20-Digit Rule", function()
    local a = bigdecimal.new("1", 0)
    local b = bigdecimal.new("3", 0)
    
    local c = a / b
    local expected = "0.33333333333333333333" -- 20 digits of 3
    assert(tostring(c) == expected, "Standard (/) operator does not conform to default 20-digit precision rule.")
end)

run_test("Division: Custom Precision and Truncation Logic", function()
    local a = bigdecimal.new("2", 0)
    local b = bigdecimal.new("3", 0)
    
    -- 2 / 3 produces 0.6666... With requested precision 2, 
    -- truncation rule requires 0.66 instead of 0.67.
    local c = bigdecimal.div(a, b, 2)
    assert(tostring(c) == "0.66", "Custom division is applying rounding or improperly propagating precision.")
end)

print("\n=== TEST SUITE COMPLETED ===")
