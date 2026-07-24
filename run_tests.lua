-- run_tests.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
package.cpath = "./build/?.so;./build/?.dylib;./build/?.dll;" .. package.cpath

local function run_spec(file_path)
    print("\n" .. string.rep("=", 50))
    print(" Running Test Suite: " .. file_path)
    print(string.rep("=", 50))
    
    local ok, err = pcall(dofile, file_path)
    if not ok then
        print("\n[X] FAILED: " .. file_path)
        print("Error details: " .. tostring(err))
        return false
    else
        print("\n[v] PASSED: " .. file_path)
        return true
    end
end

-- Pure Lua Tests
local pure_tests = {
    "tests/bigint_consistency_spec.lua",
    "tests/bigdecimal_consistency_spec.lua",
    "tests/time_test.lua"
}

-- C / GMP Tests
local oracle_tests = {
    { file = "tests/bigint_gmp_oracle.lua", module = "gmporacle" },
    { file = "tests/bigdecimal_gmp_oracle.lua", module = "gmpdec" }
}

local passed = 0
local total = 0

print("\n--------------------------------------------------")
print("          STARTING LMP TEST SUITE")
print("--------------------------------------------------")

-- Run pure Lua tests
for _, test_file in ipairs(pure_tests) do
    total = total + 1
    if run_spec(test_file) then
        passed = passed + 1
    end
end

-- Oracle tests
for _, test in ipairs(oracle_tests) do
    total = total + 1
    local has_c_module = pcall(require, test.module)
    
    if has_c_module then
        if run_spec(test.file) then
            passed = passed + 1
        end
    else
        print("\n" .. string.rep("-", 50))
        print(" [!] SKIPPED: " .. test.file)
        print(" Reason: Built C module '" .. test.module .. "' not found in ./build/")
        print(" Build C binaries first to run GMP Oracle tests.")
        print(string.rep("-", 50))
    end
end

-- Summary
print("\n" .. string.rep("=", 50))
print(string.format(" TEST RESULTS: %d/%d Passed", passed, total))
print(string.rep("=", 50) .. "\n")

if passed < total then
    os.exit(1)
end
