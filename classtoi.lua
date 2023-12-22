--- classtoi v2: finding a sweet spot between classtoi-light and classtoi-heavy
-- aka getlost v2
--
-- usage:
--
-- local class = require("class")
-- local Vehicle = class {
-- 	type = "vehicle", -- class name, optional
--
-- 	stability_threshold = 3, -- class variable, also availabe in instances
-- 	wheel_count = nil, -- doesn't do anything, but i like to keep track of variables that will need to be defined later in a subclass or a constructor
--
-- 	init = false, -- abstract class, can't be instanciated
--
-- 	is_stable = function(self) -- method, available both in class and instances
-- 		return self.wheel_count > self.stability_threshold
-- 	end
-- }
--
-- local Car = Vehicle { -- subclassing by calling the parent class; multiple inheritance possible by either chaining calls or passing several tables as arguments
-- 	type = "car",
-- 	wheel_count = 4,
-- 	color = nil,
-- 	init = function(self, color) -- constructor
-- 		self.color = color
-- 	end
-- }
-- local car = Car:new("red") -- instancing
-- print(car:is_stable(), car.color) -- true, "red"
--
-- the default class returned by require("class") contains a few other default methods that will be inherited by all subclasses
-- see line 99 and further for details & documentation
--
-- design philosophy:
-- do not add feature until we need it
-- what we want to be fast: instance creation, class & instance method call & property acces
-- do not care: class creation
--
-- and if you're wondering, no i'm not using either classtoi-heavy nor classtoi-light in any current project anymore.

--# helper functions #--

-- tostring that ignore __tostring methamethod
local function rawtostring(v)
	local mt = getmetatable(v)
	setmetatable(v, nil)
	local str = tostring(v)
	setmetatable(v, mt)
	return str
end

-- deep table copy, preserve metatable
local function copy(t, cache)
	if cache == nil then cache = {} end
	if cache[t] then return cache[t] end
	local r = {}
	cache[t] = r
	for k, v in pairs(t) do
		r[k] = type(v) == "table" and copy(v, cache) or v
	end
	return setmetatable(r, getmetatable(t))
end

-- add val to set
local function add_to_set(set, val)
	if not set[val] then
		table.insert(set, val)
		set[val] = true
	end
end

--# class creation logic #--
local new_class, class_mt

new_class = function(...)
	local class = {}
	local include = {...}
	for i=1, #include do
		local parent = include[i]
		parent = parent.__included ~= nil and parent:__included(class) or parent
		for k, v in pairs(parent) do
			class[k] = v
		end
	end
	class.__index = class
	setmetatable(class, class_mt)
	return class.__created ~= nil and class:__created() or class
end

class_mt = {
	__call = new_class,
	__tostring = function(self)
		local name = self.type and ("class %q"):format(self.type) or "class"
		return rawtostring(self):gsub("^table", name)
	end
}
class_mt.__index = class_mt

--# base class and its contents #--
-- feel free to redefine these as needed in your own classes; all of these are also optional and can be deleted.
return new_class {
	--- instanciate. arguments are passed to the (eventual) constructor :init.
	-- behavior undefined when called on an object.
	-- set to false to make class non-instanciable (will give unhelpful error on instanciation attempt).
	-- obj = class:new(...)
	new = function(self, ...)
		local obj = setmetatable({}, self)
		return obj.init ~= nil and obj:init(...) or obj
	end,
	--- constructor. arguments are passed from :new. if :init returns a value, it will be returned by :new instead of the self object.
	-- set to false to make class abstract (will give unhelpful error on instanciation attempt), redefine in subclass to make non-abstract again.
	-- init = function(self, ...) content... end
	init = nil,
	--- check if the object is an instance of this class.
	-- class:is(obj)
	-- obj:is(class)
	is = function(self, other) -- class:is(obj)
		if getmetatable(self) == class_mt then
			return getmetatable(other) == self
		else
			return other:is(self)
		end
	end,
	--- check if the object is an instance of this class or of a class that inherited this class.
	-- parentclass:issub(obj)
	-- parentclass:issub(class)
	-- obj:issub(parentclass)
	issub = function(self, other)
		if getmetatable(self) == class_mt then
			return other.__parents and other.__parents[self] or self:is(other)
		else
			return other:issub(self)
		end
	end,
	--- check if self is a class
	-- class:isclass()
	isclass = function(self)
		return getmetatable(self) == class_mt
	end,
	--- called when included in a new class. if it returns a value, it will be used as the included table instead of the self table.
	-- default function tracks parent classes and is needed for :issub to work, and returns a deep copy of the included table.
	__included = function(self, into)
		-- add to parents
		if not into.__parents then
			into.__parents = {}
		end
		local __parents = self.__parents
		if __parents then
			for i=1, #__parents do
				add_to_set(into.__parents, __parents[i])
			end
		end
		add_to_set(into.__parents, self)
		-- create copied table
		local copied = copy(self)
		copied.__parents = nil -- prevent __parents being overwritten
		return copied
	end,
	-- automatically created by __included and needed for :issub to work
	-- list and set of classes that are parents of this class: { parent_a, [parent_a] = true, parent_b, [parent_b] = true, ... }
	__parents = nil,
	--- called on the class when it is created. if it returns a value, it will be returned as the new class instead of the self class.
	__created = nil,
	--- pretty printing. type is used as the name of the class.
	type = "object",
	__tostring = function(self)
		return rawtostring(self):gsub("^table", self.type)
	end
}
