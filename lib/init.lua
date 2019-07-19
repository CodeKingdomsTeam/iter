local _ = require "rodash"

local Iterators = {}

Iterators.Skip = _.makeSymbol("Skip")

function Iterators.getIterator(source)
	if type(source) == "function" then
		return source
	elseif type(source) == "table" then
		if source[1] ~= nil then
			return ipairs(source)
		else
			return pairs(source)
		end
	end
end

function Iterators.makeIterator(iterable, next, first)
	local iterator = {
		next = next,
		iterable = iterable,
		key = first
	}
	setmetatable(
		iterator,
		{
			__call = function(self)
				return self.next, self.iterable, self.key
			end,
			__index = function(self, key)
				return Iterators[key]
			end
			-- __tostring = function(self)
			-- 	if self.parent then
			-- 		return tostring(self.parent) .. " >> " .. (self.name or tostring(self.iterable))
			-- 	else
			-- 		return "Iterator(" .. (self.name or tostring(self.iterable)) .. ")"
			-- 	end
			-- end
		}
	)
	return iterator
end

function Iterators.iter(iterable)
	local next, _, first = Iterators.getIterator(iterable)
	local iterator = Iterators.makeIterator(iterable, next, first)
	return iterator, iterable, first
end

function Iterators.makeTransformer(name, generator)
	local transform
	transform = function(parent, ...)
		local wrapArgs = {...}
		local visit, finish = generator(parent, ...)
		local iterator
		iterator =
			Iterators.iter(
			function(iterable)
				local key, value = iterator.parent:consume()
				if key == Iterators.Skip then
					local finishKey, finishValue = finish(iterator, key, value)
					if finishKey ~= nil then
						return finishKey, finishValue
					else
						return iterator:consume()
					end
				elseif key ~= nil then
					local nextKey, nextValue = visit(key, value, iterator)
					return nextKey, nextValue
				elseif finish then
					finish(iterator)
				end
			end
		)
		iterator.name = name
		iterator.parent = parent
		iterator.clone = function()
			return transform(iterator.parent:clone(), unpack(wrapArgs))
		end
		return iterator
	end
	return transform
end

function Iterators.makeCompositor(name, composer, initial)
	return function(self)
		local iterator =
			self:accumulate(
			function(current, value, key)
				return composer(current, value)
			end,
			initial
		)
		iterator.name = name
		return iterator
	end
end

function Iterators.makeMixin(setup, visited, finished)
	return function(fn, ...)
		local mixinArgs = {...}
		return function(iterator, ...)
			setup(iterator, unpack(mixinArgs))
			local visit, finish = fn(iterator, ...)
			visited = visited or _.returnsArgs
			finished = finished or _.returnsNil
			return function(...)
				return visited(iterator, visit, ...)
			end, function(...)
				return finished(iterator, finish, ...)
			end
		end
	end
end

Iterators.withIndex =
	Iterators.makeMixin(
	function(iterator, initial)
		iterator.index = initial or 0
	end,
	function(iterator, visit, key, value)
		if key ~= Iterators.Skip then
			iterator.index = iterator.index + 1
		end
		return visit(key, value)
	end
)

function Iterators:consume()
	local key, value = self.next(self.iterable, self.key)
	self.key = key
	return key, value
end

function Iterators:clone()
	return Iterators.makeIterator(self.iterable, self.next, self.key)
end

function Iterators:last()
	local result, resultKey
	for key, value in self() do
		resultKey = key
		result = value
	end
	return result, resultKey
end

function Iterators:collect()
	local object = {}
	for key, value in self() do
		object[key] = value
	end
	return object
end

Iterators.found =
	Iterators.makeTransformer(
	"found",
	function(iterator, target)
		return function(key, value, iterator)
			if value == target then
				return key, true
			else
				return iterator()
			end
		end, function()
			return false
		end
	end
)
function Iterators:includes(value)
	return self:found(value):consume()
end

Iterators.enumerate =
	Iterators.makeTransformer(
	"enumerate",
	Iterators.withIndex(
		function(parent, fn)
			return function(key, value, iterator)
				return parent.index, value
			end
		end
	)
)

Iterators.map =
	Iterators.makeTransformer(
	"map",
	function(iterator, fn)
		return function(key, value, iterator)
			return key, fn(value, key, iterator)
		end
	end
)

Iterators.pickBy =
	Iterators.makeTransformer(
	"pickBy",
	function(iterator, fn)
		return function(key, value, iterator)
			if fn(value, key, iterator) then
				return key, value
			else
				return Iterators.Skip
			end
		end
	end
)
Iterators.filter = _.compose(Iterators.pickBy, Iterators.enumerate)

function Iterators:pick(values)
	return self:pickBy(
		function(value)
			return Iterators.iter(values):includes(value)
		end
	)
end

Iterators.omit =
	Iterators.makeTransformer(
	"omit",
	function(iterator, test)
		return function(key, value, iterator)
			if value ~= test then
				return key, value
			else
				return Iterators.Skip
			end
		end
	end
)

Iterators.accumulate =
	Iterators.makeTransformer(
	"accumulate",
	function(iterator, fn, initial)
		return function(key, value, iterator)
			iterator.current = fn(iterator.current or initial, value, key, iterator)
			return key, iterator.current
		end
	end
)
Iterators.reduce = _.compose(Iterators.accumulate, Iterators.last)

Iterators.count =
	Iterators.makeCompositor(
	"count",
	function(current)
		return current + 1
	end,
	0
)
Iterators.counted = _.compose(Iterators.count, Iterators.last)

Iterators.sum =
	Iterators.makeCompositor(
	"sum",
	function(current, value)
		return current + value
	end,
	0
)
Iterators.summed = _.compose(Iterators.sum, Iterators.last)

-- Iterators.average =
-- 	Iterators.makeTransformer(
-- 	"average",
-- 	Iterators.withIndex(
-- 		function(parent, fn)
-- 			return function(key, value, iterator)
-- 				return parent.index, value
-- 			end
-- 		end
-- 	)
-- )
-- Iterators.averaged = _.compose(Iterators.sum, Iterators.last)

Iterators.max = Iterators.makeCompositor("max", math.max)
Iterators.maxed = _.compose(Iterators.max, Iterators.last)

Iterators.min = Iterators.makeCompositor("min", math.min)
Iterators.minned = _.compose(Iterators.min, Iterators.last)

return Iterators.iter
