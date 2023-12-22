-- can be used to compare different versions: lua performance/performance.lua classtoi-light.lua classtoi.lua classtoi-heavy.lua

-- load libs to test
if not arg[1] then arg[1] = "../classtoi.lua" end

local totest = {}
local referencesource = arg[1]
for i=1, #arg do
	totest[arg[i]] = dofile(arg[i])
end

-- setup results
local results = {}
local function time(source, title, f)
	collectgarbage()
	local start = os.clock()
	for i=0, 5e4 do f() end
	local result = os.clock() - start

	if not results[title] then results[title] = {} end
	results[title][source] = result
end

-- perform benchmark
for source, class in pairs(totest) do
	do
		time(source, "class creation", function()
			local A = class()
		end)
	end

	do
		local A = class()

		time(source, "instance creation", function()
			local a = A:new()
		end)
	end

	do
		local A = class {
			foo = function(self)
				return 1
			end
		}

		local a = A:new()

		time(source, "instance method invocation", function()
			a:foo()
		end)

		time(source, "class method invocation", function()
			A:foo()
		end)
	end

	do
		local A = class {
			foo = function(self)
				return 1
			end
		}

		local B = A()

		local b = B:new()

		time(source, "inherited instance method invocation", function()
			b:foo()
		end)

		time(source, "inherited class method invocation", function()
			B:foo()
		end)
	end
end

-- display results
for test, sources in pairs(results) do
	print(test..":")
	for i=1, #arg do
		local source = arg[i]
		local result = sources[source]
		local ratio = math.floor(result/sources[referencesource]*1000)/1000
		print(("\t%s: %ss (x%s)"):format(source, result, ratio))
	end
end
