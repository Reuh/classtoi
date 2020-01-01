local class = dofile(arg[1] or "../classtoi.lua")

local function time(title, f)
	collectgarbage()
	local start = os.clock()
	for i=0, 5e4 do f() end
	print(title, os.clock() - start)
end

do
	time("class creation", function()
		local A = class()
	end)
end

do
	local A = class()

	time("instance creation", function()
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

	time("instance method invocation", function()
		a:foo()
	end)

	time("class method invocation", function()
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

	time("inherited instance method invocation", function()
		b:foo()
	end)

	time("inherited class method invocation", function()
		B:foo()
	end)
end
