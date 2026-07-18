--lmp.lua
local bigint = {}
local mt = {} -- metatable

-- LuaJIT stores numbers as IEEE 754 double-precision floats by default.
-- The maximum safe integer limit is 2^53 - 1 (approx. 9 x 10^15).
-- To prevent precision loss during chunk multiplication (chunk * chunk),
-- the chunk size 'n' must be 7 (since 10^7 * 10^7 = 10^14 < 2^53).
-- It has been leaved as 9 to use full capability of lua5.4+, but feel free to modify it
local n = 9
local BASE = math.floor(10 ^ n) -- 10^9
local FMT_STR = "%0" .. n .. "d"


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

function bigint.mult(a, b)
	local result = { digits = {} }
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

	while #result.digits > 1 and result.digits[#result.digits] == 0 do
		table.remove(result.digits)
	end

	result.sign = a.sign * b.sign

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


return bigint
