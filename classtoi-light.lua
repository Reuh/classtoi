--- Reuh's light class library version 0.1.0. Lua 5.1-5.3 and LuaJIT compatible.
-- Lighter and faster version of classtoi, keeping the same syntax but with uncommon features removed.
-- Features:
-- * class creation and inheritance with class(table...) or subclass(table...) (left-to-right priority). Parent classes are shallowly copied on creation in the new class.
-- * instance creation with class:new, which calls the :init constructor (which can returns another object instead of the automaticaly created one)
-- * every methamethod supported in instances except __index
-- * a default :is method to check if an object is an instance of a class (ignore parents): class:is(obj) or obj:is(class) returns true if obj is of class
-- * a default __tostring method and __name attribute for pretty printing of objects and classes
-- Main differences from classtoi:
-- * methamethods are only applied to instances and not classes
-- * can't redefine __init
-- * instance constructor is renamed to :init
-- * inherited fields and methods are copied on creation; adding a new field to a parent class after creation will not affect child classes
-- * is can only be called in its class:is(object) or object:is(class) form (returns true if object is of class), and ignore parents
-- * no class commons support
-- Please note that if you redefine :new or :is, they will be used instead of the class default.

local newClass, class_mt
newClass = function(...)
	local class = {}
	for _, mixin in ipairs({...}) do
		for k, v in pairs(mixin) do
			class[k] = v
		end
	end
	class.__index = class
	return setmetatable(class, class_mt)
end
class_mt = {
	new = function(self, ...)
		local obj = setmetatable({}, self)
		return obj.init and obj:init(...) or obj
	end,
	is = function(self, other)
		if getmetatable(self) == class_mt then -- class:is(obj)
			return getmetatable(other) == self
		else -- obj:is(class)
			return getmetatable(self) == other
		end
	end,
	__call = newClass,
	__tostring = function(self)
		local mt = getmetatable(self)
		setmetatable(self, nil)
		local str = tostring(self)
		setmetatable(self, mt)
		return str:gsub("^table", "class")
	end
}
class_mt.__index = class_mt

-- base class
return newClass {
	__name = "object",
	__tostring = function(self)
		local mt = getmetatable(self)
		setmetatable(self, nil)
		local str = tostring(self)
		setmetatable(self, mt)
		return str:gsub("^table", self.__name)
	end
}
