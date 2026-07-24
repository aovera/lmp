--lmp.lua
local bigint = {}
local mt = {} -- metatable

-- LuaJIT stores numbers as IEEE 754 double-precision floats by default.
-- The maximum safe integer limit is 2^53 - 1 (approx. 9 x 10^15).
-- To prevent precision loss during chunk multiplication (chunk * chunk),
-- the chunk size 'n' must be 7 (since 10^7 * 10^7 = 10^14 < 2^53).
local n = 7
local BASE = math.floor(10 ^ n) -- 10^7
local FMT_STR = "%0" .. n .. "d"
local KARATSUBA_THRESHOLD = 150 -- 150 * 7 = 1050 digits


local function trim(obj)
	-- Delete zeros in the beginning of number
	while #obj.digits > 1 and obj.digits[#obj.digits] == 0 do
		table.remove(obj.digits)
	end

	if #obj.digits == 1 and obj.digits[1] == 0 then
		obj.sign = 1 -- 0 always positive
	end

	return obj
end

--New number creator
function bigint.new(str_num)
	local obj = { digits = {} , sign = 1}

	if str_num:sub(1, 1) == "-" then
		obj.sign = -1
		str_num = str_num:sub(2) --remove sign
	elseif str_num:sub(1, 1) == "+" then
		str_num = str_num:sub(2) --remove sign
	end

	if str_num == "" then
		str_num = "0"
	end

	--Little endian typing
	local i = #str_num
	while i > 0 do
		local start_index = i - n + 1
		if start_index < 1 then
			start_index = 1
		end
											        
		local chunk = str_num:sub(start_index, i)
		table.insert(obj.digits, tonumber(chunk))

		i = start_index - 1
	end
	trim(obj)

	setmetatable(obj, mt)
	return obj
end

function bigint.to_str(obj)
	if #obj.digits == 0 then
		return "0"
	end
	local str = tostring(obj.digits[#obj.digits])

	for i = #obj.digits - 1, 1, -1 do
		--decode and string concat
		str = str .. string.format(FMT_STR, obj.digits[i])
	end
	
	if obj.sign == -1 and not (#obj.digits == 1 and obj.digits[1] == 0) then
		str = "-" .. str
	end

	return str
end


--Return 1 if a > b, if equal 0, -1 if a < b
local function abs_compare(a, b)
	if #a.digits ~= #b.digits then
		return (#a.digits > #b.digits and 1) or -1
	end

	for i = #a.digits, 1, -1 do
		if a.digits[i] ~= b.digits[i] then
			return (a.digits[i] > b.digits[i] and 1) or -1
		end
	end

	return 0
end

function bigint.compare(a, b)
	if #a.digits == 1 and a.digits[1] == 0 and #b.digits == 1 and b.digits[1] == 0 then
		return 0
	end

	if a.sign ~= b.sign then
		return (a.sign > b.sign and 1) or -1
	end

	local comp = abs_compare(a, b)
	if a.sign == 1 then
		return comp
	else
		return -comp
	end

end


local function raw_add(a, b)
	local result = { digits = {} , sign = 1}
	local carry = 0
	local i = 1

	while i <= #a.digits or i <= #b.digits or carry > 0 do
		local digit_a = a.digits[i] or 0
		local digit_b = b.digits[i] or 0

		local sum = digit_a + digit_b + carry
		carry = math.floor(sum / BASE)
		local new_digit = sum % BASE

		table.insert(result.digits, new_digit)
		i = i + 1
	end

	setmetatable(result, mt)
	return result
end

local function raw_sub(a, b)
	local result = { digits = {}, sign = 1}
	local borrow = 0
	for i = 1, #a.digits do
		local digit_a = a.digits[i]
		local digit_b = b.digits[i] or 0

		local diff = digit_a - digit_b - borrow
		if diff < 0 then
			diff = diff + BASE
			borrow = 1
		else
			borrow = 0
		end

		result.digits[i] = diff
	end

	setmetatable(result, mt)
	return result
end

function bigint.add(a, b)
	if a.sign == b.sign then
		local result = raw_add(a, b)
		result.sign = a.sign
		return trim(result)
	else
		local cmp = abs_compare(a, b)
		if cmp >= 0 then
			local result = raw_sub(a, b)
			result.sign = a.sign
			return trim(result)
		else
			local result = raw_sub(b, a)
			result.sign = b.sign
			return trim(result)
		end
	end
	
end

function bigint.sub(a, b)
	if a.sign ~= b.sign then
		-- a - (-b) = a + b or -a - b = -(a + b)
		local result = raw_add(a, b)
		result.sign = a.sign
		return trim(result)
	else
		local cmp = abs_compare(a, b)
		if cmp >= 0 then
			local result = raw_sub(a, b)
			result.sign = a.sign
			return trim(result)
		else
			local result = raw_sub(b, a)
			result.sign = -a.sign
			return trim(result)
		end
	end

end

-- Old bigint.mult() before karatsuba implementation
--[[
function bigint.mult(a, b)
	local result = { digits = {}, sign = 1}
	local max_digit = #a.digits + #b.digits
	for i = 1, max_digit do
		result.digits[i] = 0
	end
	
	for i = 1, #a.digits do
		local carry = 0
		for ii = 1, #b.digits do
			local target_index = i + ii - 1
			local current_result = result.digits[target_index]
			local mult = (a.digits[i] * b.digits[ii]) + current_result + carry

			carry = math.floor(mult / BASE)
			result.digits[target_index] = mult % BASE
		end

		if carry > 0 then
			result.digits[i + #b.digits] = result.digits[i + #b.digits] + carry
		end
	end

	result.sign = a.sign * b.sign
	result = trim(result)

	setmetatable(result, mt)
	return result
end
]]--


local function base_mult(a, b)
    if #a == 0 or #b == 0 then return {} end
    if (#a == 1 and a[1] == 0) or (#b == 1 and b[1] == 0) then return {0} end
    
    local res = {}
    for i = 1, #a + #b do res[i] = 0 end
    
    for i = 1, #a do
        local carry = 0
        for j = 1, #b do
            local target = i + j - 1
            local mult = (a[i] * b[j]) + res[target] + carry
            carry = math.floor(mult / BASE)
            res[target] = mult % BASE
        end
        if carry > 0 then
            res[i + #b] = res[i + #b] + carry
        end
    end
    while #res > 1 and res[#res] == 0 do table.remove(res) end
    return res
end

--Karatsuba helper
local function add_arrays(a, b)
	local result = {}
	local carry = 0
	local max_len = math.max(#a, #b)
	
	for i = 1, max_len do
		local sum = (a[i] or 0) + (b[i] or 0) + carry
		if sum >= BASE then
			sum = sum - BASE
			carry = 1
		else
			carry = 0
		end
		result[i] = sum
	end

	if carry > 0 then
		result[max_len + 1] = carry
	end

	return result
end

--Karatsuba helper
local function sub_arrays(a, b)
	local result = {}
	local borrow = 0

	local max_len = math.max(#a, #b)
	for i = 1, max_len do
		local diff = (a[i] or 0) - (b[i] or 0) - borrow
		if diff < 0 then
			diff = diff + BASE
			borrow = 1
		else
			borrow = 0
		end
		result[i] = diff
	end

	while #result > 1 and result[#result] == 0 do table.remove(result) end
	return result
end

--Karatsuba helper
local function split_arrays(a, m)
	local low, high = {}, {}
	
	for i = 1, m do
		low[i] = a[i] or 0
	end
	while #low > 1 and low[#low] == 0 do
		table.remove(low)
	end
	if #low == 0 then
		low = {0}
	end

	for i = m + 1, #a do
		high[i - m] = a[i]
	end
	if #high == 0 then
		high = {0}
	end

	return low, high
end

--Karatsuba recursion core
local function karatsuba_core(a, b)
	local len_a = #a
	local len_b = #b

	if len_a <= KARATSUBA_THRESHOLD or len_b <= KARATSUBA_THRESHOLD then
        return base_mult(a, b)
    end

	local m = math.floor((math.max(len_a, len_b) + 1) / 2)
	
	local a0, a1 = split_arrays(a, m)
	local b0, b1 = split_arrays(b, m)

	local z0 = karatsuba_core(a0, b0)
	local z2 = karatsuba_core(a1, b1)

	local a0_plus_a1 = add_arrays(a0, a1)
	local b0_plus_b1 = add_arrays(b0, b1)

	local z1_temp = karatsuba_core(a0_plus_a1, b0_plus_b1)
	local z1 = sub_arrays(sub_arrays(z1_temp, z0), z2)

	-- z2 * BASE^(2m) + z1 * BASE^m + z0
	local result = {}
	local max_idx = 0 --manual control

	for i = 1, #z0 do
		result[i] = z0[i]
		if i > max_idx then max_idx = i end
	end

	for i = 1, #z1 do
		local target = i + m
		result[target] = (result[target] or 0) + z1[i]
		if target > max_idx then max_idx = target end
	end

	for i = 1, #z2 do
		local target = i + 2 * m
		result[target] = (result[target] or 0) + z2[i]
		if target > max_idx then max_idx = target end
	end

	-- Carry normalization
	local carry = 0
	for i = 1, max_idx do
		local sum = (result[i] or 0) + carry
		if sum >= BASE then
			carry = math.floor(sum / BASE)
			result[i] = sum % BASE
		else
			carry = 0
			result[i] = sum
		end
	end

	while carry > 0 do
		max_idx = max_idx + 1
		result[max_idx] = carry % BASE
		carry = math.floor(carry / BASE)
	end

	while #result > 1 and result[#result] == 0 do table.remove(result) end
	return result
end


function bigint.mult(a, b)
	
	local result_digits = karatsuba_core(a.digits, b.digits)
	local result = {
		digits = result_digits,
		sign = a.sign * b.sign
	}

	result = trim(result)

	setmetatable(result, mt)
	return result
end


function bigint.divmod(a, b)
    if #b.digits == 1 and b.digits[1] == 0 then
        error("Division by zero")
    end
    local cmp = abs_compare(a, b)
    if cmp == -1 then
        local quotient = bigint.new("0")
        local remainder = bigint.new(bigint.to_str(a))
        return quotient, remainder
    elseif cmp == 0 then
        local quotient = bigint.new("1")
        quotient.sign = a.sign * b.sign
        local remainder = bigint.new("0")
        return quotient, remainder
    end
    
    local quotient = { digits = {}, sign = 1}
    local remainder = bigint.new("0")
    local abs_b = { digits = b.digits, sign = 1}
    
    for i = #a.digits, 1, -1 do
        -- Mult remainder with 10^9 and add new digit
        if not (#remainder.digits == 1 and remainder.digits[1] == 0) then
            table.insert(remainder.digits, 1, a.digits[i])
        else
            remainder.digits[1] = a.digits[i]
        end
        
        local c = 0
        
        if abs_compare(remainder, abs_b) >= 0 then
            -- BINARY SEARCH
            local low = 0
            local high = BASE - 1
            
            while low <= high do
                local mid = math.floor((low + high) / 2)
                
                -- Temporary multiplication
                local mid_bigint = { digits = {mid}, sign = 1 }
                local temp_mult = bigint.mult(abs_b, mid_bigint)
                
                if abs_compare(temp_mult, remainder) <= 0 then
                    c = mid          -- Suitable candidate
                    low = mid + 1
                else
                    high = mid - 1
                end
            end
            
            -- Substract at once
            local c_bigint = { digits = {c}, sign = 1 }
            local subtrahend = bigint.mult(abs_b, c_bigint)
            remainder = bigint.sub(remainder, subtrahend)
        end
        
        table.insert(quotient.digits, 1, c)
    end
    
    quotient = trim(quotient)
    remainder = trim(remainder)
    quotient.sign = a.sign * b.sign
    remainder.sign = a.sign
    remainder = trim(remainder)
    
	setmetatable(quotient, mt)
	setmetatable(remainder, mt)
    return quotient, remainder
end

function bigint.power(a, b)
	local result = bigint.new("1")
	if #b.digits == 1 and b.digits[1] == 0 then
		setmetatable(result, mt)
		return result-- n ^ 0 = 1
	end

	if bigint.compare(b, bigint.new("0")) == -1 then
		error("Illegal operation! Power < 0!")
	end


	local i = bigint.new("0")
	local one = bigint.new("1")
	while bigint.compare(i, b) ~= 0 do--while b >= 1
		result = bigint.mult(result, a)
		i = bigint.add(i, one)
	end

	setmetatable(result, mt)
	return result
end


-- Type converter
local function to_bigint(val)
    if type(val) == "table" and val.digits then
        return val
    else
        return bigint.new(tostring(val))
    end
end

-- To string
mt.__tostring = function(obj)
    return bigint.to_str(obj)
end

-- Add a + b
mt.__add = function(a, b)
    return bigint.add(to_bigint(a), to_bigint(b))
end

-- Sub a - b
mt.__sub = function(a, b)
    return bigint.sub(to_bigint(a), to_bigint(b))
end

-- Mult a * b
mt.__mul = function(a, b)
    return bigint.mult(to_bigint(a), to_bigint(b))
end

-- Integer division a // b
mt.__idiv = function(a, b)
    local q, _ = bigint.divmod(to_bigint(a), to_bigint(b))
    return q
end

-- Division, same with integer division, compatibility with luajit
mt.__div = function(a, b)
    local q, _ = bigint.divmod(to_bigint(a), to_bigint(b))
    return q
end

-- Mod a % b
mt.__mod = function(a, b)
    local _, r = bigint.divmod(to_bigint(a), to_bigint(b))
    return r
end

-- a < b
mt.__lt = function(a, b)
    return bigint.compare(to_bigint(a), to_bigint(b)) == -1
end

-- 8. a <= b
mt.__le = function(a, b)
    local cmp = bigint.compare(to_bigint(a), to_bigint(b))
    return cmp == -1 or cmp == 0
end

-- a == b
mt.__eq = function(a, b)
    return bigint.compare(to_bigint(a), to_bigint(b)) == 0
end

mt.__pow = function(a, b)
	local p = bigint.power(to_bigint(a), to_bigint(b))
	return p
end


return bigint
