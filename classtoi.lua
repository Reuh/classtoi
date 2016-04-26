--- Reuh's class library version 0.1.1. Lua 5.1-5.3 and LuaJit compatible.
-- Objects and classes behavior are identical, so you can consider this to be prototype-based.
-- Features:
-- * Multiple inheritance with class(parents...) or someclass(newstuff...)
-- * Every metamethods supported
-- * Everything in a class can be redefined (and will be usable in an object) (except __super)
-- * Preserve parents metamethods if already set
-- * Instanciate with class:new(...)
-- * Test inheritance relations with class/object.is(thing, isThis)
-- * Call object:new(...) on instanciation
-- * Call class.__inherit(class, inheritingClass) when creating a class inheriting the previous class. If class.__inherit returns a value, it will
--   be used as the parent table instead of class, allowing some pretty fancy behavior (it's like an inheritance metamethod).
-- * Implements Class Commons
-- * I don't like to do this, but you can redefine every field and metamethod after class creation (except __index and __super).
-- Not features (things you may want to know):
-- * Will set the metatable of all parent classes/tables if no metatable is set (the table will be its own metatable).
-- * You can't redefine __super (any __super you define will be only avaible by searching in the default __super contents).
-- * Redefining __super or __index after class creation will break everything (though it should be ok with new, is, __call and everything else).
-- * When creating a new class, the methods new, is, __call, __index and __super will always be redefined, so trying to get theses fields
--   will return the default method and not the one you've defined. However, theses defaults will be replaced by yours automatically on instanciation,
--   except __super and __index, but __index should call your __index and act like you expect. __super will however always be the default one
--   and doesn't proxy in any way yours.
--
-- Please also note that the last universal ancestor of the classes (defined here in BaseClass) sets the default __tostring method for nice
-- class-name-printing. Unlike previous text however, it is done in a normal inheritance-way and can be rewritten without any problem.

-- Lua versions compatibility
local unpack = table.unpack or unpack

--- All Lua 5.3 metamethods.
local metamethods = {
	"__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__idiv",
	"__band", "__bor", "__bxor", "__bnot", "__shl", "__shr", "__tostring",
	"__concat", "__len", "__eq", "__lt", "__le", "__index", "__newindex", "__call", "__gc"
}

local different --- When set, every class __index method will only return a value different from this one.
--- When using a proxied method, contains the last indexed class.
-- This is used for class.is(object); lastIndex will contain class so the is method can react accordingly, without having to be
-- re-set for each class (and therefore doesn't break the "different" mecanism).
local lastIndexed
local makeclass, methods, BaseClass

--- Classes defaults methods: will be re-set on each class creation.
-- If you overwrite them, you will only be able to call them from an object.
-- Methods starting with a "!" are "proxied methods": they're not present in the class table and will only be called through __index,
-- allowing more control over it (for example having access to lastIndexed).
methods = {
	--- Create an object from the class.
	-- In pratise, this only subclass the class and call the new method on it, so technically an object is a class.
	-- Objects are exaclty like classes, but the __call metamethod will be replaced by one found in the parents,
	-- or nil if doesn't exist (so an object is not directly subclassable).
	-- (If no __call method is defined in a parent, you won't be able to call the object, but obj.__class will still
	-- returns the default (subclassing) method, from one of the parents classes.)
	-- The same happens with :new and :is, but since they're not metamethods, if not defined in a parent you won't
	-- notice any difference.
	-- TL;DR (since I think I'm not really clear): you can redefine __call, :new and :is in parents and use them in objects only.
	new = function(self, ...)
		local obj = self()
		-- Setting class methods to the ones found in parents (we use rawset in order to avoid calling the __newindex metamethod)
		different = methods.new     rawset(obj, "new", obj:__index("new") or nil)
		different = methods["!is"]  rawset(obj, "is", obj:__index("is") or nil)
		different = methods.__call  rawset(obj, "__call", obj:__index("__call") or nil)
		different = nil
		-- Call constructor
		if obj.new ~= methods.new and type(obj.new) == "function" then obj:new(...) end
		return obj
	end,
	--- Returns true if self is other or a subclass of other.
	-- If other is nil, will return true if self is a subclass of the class who called this method.
	-- Examples:
	-- class.is(a) will return true if a is any class or object
	-- (class()):is(class) will return true ((class()) is a subclass of class)
	-- (class()).is(class) will return false (class isn't a subclass of (class()))
	["!is"] = function(self, other)
		if type(self) ~= "table" then return false end
		if other == nil then other = lastIndexed end
		if self == other then return true end
		for _, t in ipairs(self.__super) do
			if t == other then return true end
			if t.is == methods["!is"] and t:is(other) then return true end
		end
		return false
	end,
	--- Subclass the class: will create a class inheriting self and ... (... will have priority over self).
	__call = function(self, ...)
		local t = {...}
		table.insert(t, self)
		return makeclass(unpack(t))
	end,
	--- Internal value getting; this follows a precise search order.
	-- For example: class(Base1, Base2){stuff}
	-- When getting a value from the class, it will be first searched in stuff, then in Base2, then in all Base2 parents,
	-- then in Base1, then in Base1 parents.
	-- A way to describe this will be search in the latest added tables (from the farthest child to the first parents), from left-to-right.
	__index = function(self, k)
		local proxied = methods["!"..tostring(k)]
		if proxied ~= nil and proxied ~= different then -- proxied methods
			lastIndexed = self
			return proxied
		end
		for _, t in ipairs(self.__super) do -- search in super (will auto-follow __index metamethods)
			local val = t[k]
			if val ~= nil and val ~= different then return val end
			-- If different search is on and the direct t[k] returns an identical value, force the __index metamethod search.
			if different ~= nil and getmetatable(t) and getmetatable(t).__index then
				local val = getmetatable(t):__index(k)
				if val ~= nil and val ~= different then return val end
			end
		end
	end
}

--- Create a new class width parents ... (left-to-right priority).
function makeclass(...)
	local class = {
		__super = {} -- parent classes/tables list
	}
	for k, v in pairs(methods) do -- copy class methods
		if k:sub(1, 1) ~= "!" then class[k] = v end -- except proxied methods
	end
	for _, t in ipairs({...}) do -- fill super
		if getmetatable(t) == nil then setmetatable(t, t) end -- auto-metatable the table
		if type(t.__inherit) == "function" then t = t:__inherit(class) or t end -- call __inherit callback
		table.insert(class.__super, t)
	end
	-- Metamethods query are always raw and thefore don't follow our __index, so we need to manually define thoses.
	for _, metamethod in ipairs(metamethods) do
		local inSuper = class:__index(metamethod)
		if class[metamethod] == nil and inSuper then
			class[metamethod] = inSuper
		end
	end
	return setmetatable(class, class)
end

--- The class which will be a parents for all the other classes.
-- We add some pretty-printing default in here. We temporarly remove the metatable in order to avoid a stack overflow.
BaseClass = makeclass {
	__tostring = function(self)
		local mt = getmetatable(self)
		setmetatable(self, nil)
		local str = ("class (%s)"):format(tostring(self))
		setmetatable(self, mt)
		return str
	end
}

--- Class Commons implementation.
-- https://github.com/bartbes/Class-Commons
if common_class and not common then
	common = {}
	-- class = common.class(name, table, parents...)
	function common.class(name, table, ...)
		table.new = table.init
		return BaseClass(table, ...)
	end
	-- instance = common.instance(class, ...)
	function common.instance(class, ...) return class:new(...) end
end

return BaseClass
