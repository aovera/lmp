local bigint = require("./bigint")
local bigdecimal = {}
local mt = {} --metatable

local function adjust_scale(bint, current_scale, target_scale)
	local diff = target_scale - current_scale
	if diff > 0 then
		local mul = bigint.new("1" .. string.rep("0", diff)) --calculate the multiplier
		return bint * mul
	elseif diff < 0 then
		local div = bigint.new("1" .. string.rep("0", -diff))
		return bint / div
	end

	return bint
end


--new decimal
function bigdecimal.new(str_num, scale_limit)
	local obj = { bint = nil, scale = 0}

	local dot_index = str_num:find("[.,]")
	local str = str_num
	local curr_scale = 0

	if dot_index then
		local int = str_num:sub(1, dot_index - 1)
		local decimal = str_num:sub(dot_index + 1)
		
		curr_scale = #decimal
		str = int .. decimal
	end

	local newint = bigint.new(str)

	if scale_limit then
		obj.bint = adjust_scale(newint, curr_scale, scale_limit)
		obj.scale = scale_limit
	else
		obj.bint = newint
		obj.scale = curr_scale
	end

	setmetatable(obj, mt)
	return obj
end

--big decimal to string
function bigdecimal.to_str(obj)
	local str = bigint.to_str(obj.bint)
	if obj.scale == 0 then
		return str
	end

	local is_neg = str:sub(1, 1) == "-"
	if is_neg then
		str = str:sub(2)
	end

	while #str <= obj.scale do
		str = "0" .. str
	end

	local cut = #str - obj.scale
	local result = str:sub(1, cut) .. "." .. str:sub(cut + 1)

	return is_neg and ("-" .. result) or result
end

mt.__tostring = function(obj) return bigdecimal.to_str(obj) end


local function align_and_execute(a, b, op)
	local max_scale = math.max(a.scale, b.scale)

	local new_a = adjust_scale(a.bint, a.scale, max_scale)
	local new_b = adjust_scale(b.bint, b.scale, max_scale)

	local result_bint
	if op == "add" then
		result_bint = new_a + new_b
	elseif op == "sub" then
		result_bint = new_a - new_b
	end

	local result = { bint = result_bint, scale = max_scale }

	setmetatable(result, mt)
	return result
end

function bigdecimal.add(a, b) return align_and_execute(a, b, "add") end
function bigdecimal.sub(a, b) return align_and_execute(a, b, "sub") end

mt.__add = function(a, b) return bigdecimal.add(a, b) end
mt.__sub = function(a, b) return bigdecimal.sub(a, b) end


function bigdecimal.mult(a, b)
	local result = {
		bint = a.bint * b.bint,
		scale = a.scale + b.scale
	}

	setmetatable(result, mt)
	return result
end

mt.__mul = function(a, b) return bigdecimal.mult(a, b) end

function bigdecimal.div(a, b, precision)
    if #b.bint.digits == 1 and b.bint.digits[1] == 0 then
        error("Division by zero!")
    end

    -- Default 20 digits
    precision = precision or 20

    -- Shifting
    local diff = precision + b.scale - a.scale
    local result_bint

    if diff >= 0 then
        local mul = bigint.new("1" .. string.rep("0", diff))
        local a_extended = a.bint * mul
        result_bint = a_extended / b.bint
    else
        local mul = bigint.new("1" .. string.rep("0", -diff))
        local b_extended = b.bint * mul
        result_bint = a.bint / b_extended
    end

    local result = {
        bint = result_bint,
        scale = precision
    }

    setmetatable(result, mt)
    return result
end


mt.__div = function(a, b) return bigdecimal.div(a, b) end

function bigdecimal.compare(a, b)
	local max_scale = math.max(a.scale, b.scale)

	local new_a = adjust_scale(a.bint, a.scale, max_scale)
	local new_b = adjust_scale(b.bint, b.scale, max_scale)

	return bigint.compare(new_a, new_b)
end

-- a == b
mt.__eq = function(a, b)
    return bigdecimal.compare(a, b) == 0
end

-- a < b
mt.__lt = function(a, b)
    return bigdecimal.compare(a, b) == -1
end

-- a <= b
mt.__le = function(a, b)
    local cmp = bigdecimal.compare(a, b)
    return cmp == -1 or cmp == 0
end

return bigdecimal
