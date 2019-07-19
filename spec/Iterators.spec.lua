local Iterators = require "Iterators"

local function assertKV(key, value, actualKey, actualValue)
	assert.equal(key, actualKey)
	assert.equal(value, actualValue)
end

describe(
	"Iterators",
	function()
		it(
			"Can consume",
			function()
				local iterator = Iterators.iter({10, 20, 30})
				assertKV(1, 10, iterator:consume())
				assertKV(2, 20, iterator:consume())
				assertKV(3, 30, iterator:consume())
				assertKV(nil, nil, iterator:consume())
			end
		)
		it(
			"Can consume with map",
			function()
				local iterator =
					Iterators.iter({10, 20, 30}):map(
					function(value)
						return value * 2
					end
				)
				assertKV(1, 20, iterator:consume())
				assertKV(2, 40, iterator:consume())
				assertKV(3, 60, iterator:consume())
				assertKV(nil, nil, iterator:consume())
			end
		)
		it(
			"Can clone and consume",
			function()
				local iterator =
					Iterators.iter({10, 20, 30}):map(
					function(value)
						return value * 2
					end
				):filter(
					function(value)
						return value < 50
					end
				)
				local iterator2 = iterator:clone()
				assertKV(1, 20, iterator:consume())
				assertKV(2, 40, iterator:consume())
				assertKV(nil, nil, iterator:consume())
				assertKV(1, 20, iterator2:consume())
				assertKV(2, 40, iterator2:consume())
				assertKV(nil, nil, iterator2:consume())
			end
		)
		it(
			"Can collect with map",
			function()
				local iterator =
					Iterators.iter({10, 20, 30}):map(
					function(value)
						return value * 2
					end
				)
				assert.are_same({20, 40, 60}, iterator:collect())
			end
		)
		it(
			"Can collect with filter",
			function()
				local iterator =
					Iterators.iter({10, 20, 30}):filter(
					function(value)
						return value ~= 20
					end
				)
				assert.are_same({10, 30}, iterator:collect())
			end
		)
		it(
			"Can get the count of an array",
			function()
				assert.equal(3, Iterators.iter({10, 20, 30}):counted())
			end
		)
		it(
			"Can sum an array",
			function()
				assert.equal(60, Iterators.iter({10, 20, 30}):summed())
			end
		)
		it(
			"Can get the count of a table",
			function()
				assert.equal(3, Iterators.iter({a = 10, b = 20, c = 30}):counted())
			end
		)
		it(
			"Can perform map-reduce",
			function()
				local iterator =
					Iterators.iter({a = 10, b = 20, c = 30}):map(
					function(value)
						return value * 2
					end
				):map(
					function(value)
						return value + 2
					end
				):sum()
				assert.equal(126, iterator:last())
			end
		)
	end
)
