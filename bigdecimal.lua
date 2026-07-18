local bigint = require("lmp.bigint")
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
	if #b.bint == 1 and b.bint[1] == 0 then
		error("Division by zero!")
	end

	-- Default 20 digits
	precision = precision or 20

	local max_scale = math.max(a.scale, b.scale) + precision

	local mul = bigint.new("1" .. string.rep("0", max_scale))
    local a_extended = a.bint * mul

	local result_bint = a_extended / b.bint

	local end_scale = max_scale + a.scale - b.scale
	local result = {
		bint = result_bint,
		scale = end_scale
	}

	setmetatable(result, mt)
	return result
end

mt.__div = function(a, b) return bigdecimal.div(a, b) end

return bigdecimal
