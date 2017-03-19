-- cmodule
-- v0.1.0
 
-- todo:
-- * document
-- * look for optimizations
-- * investigate better ways to handle dependency cycles
-- * support exported projects
--      - detect whether program is running in Codea or exported project
--      - reverse engineer exported project file layout
--      - load from alternate location when running an exported project
 
-- import global functions
local loadstring, fopen = loadstring, io.open
local insert = table.insert
local format, rep = string.format, string.rep
local setfenv, setmetatable = setfenv, setmetatable
local pairs, ipairs = pairs, ipairs
 
-- loaded modules
local _modules = {}

-- loaded exports
local _exports = {}

-- keep track of dependencies, actually a reverse list
-- so _rdependencies[A][B] is true if A was loaded while B was being loaded
-- so A should occur first in a serialisation of the libraries
local _rdependencies = {}

-- loaded environments
local _envs = {}
local _nenv = 0

local function pushEnv(t)
    t = t or {}
    table.insert(_envs,t)
    _nenv = _nenv + 1
end

local function popEnv()
    local t = table.remove(_envs,_nenv)
    _nenv = _nenv - 1
    return t
end

local function currentEnv()
    return _envs[_nenv]
end

-- temporary storage for local exports
local _tmpexports
 
-- search path projects
local _path = nil
 
-- unique module environment key to specify caching options
local function opt_cache() return opt_cache end
 
-- path to Codea's document's directory
local _docs = os.getenv("HOME") .. "/Documents/"
 
-- name of currently running project
local _this = nil    -- set by cmodule()
 
-- boilerplate function headers for modules
local _importHeader = "return function(_M, __proj, __file, __pathto, cinclude)"
local _loadHeader = "return function(__proj, __file, __pathto)"
 
-- convert codea path to filesystem path
local function _fspath(p, f)
    return _docs .. p .. ".codea/" .. f
end
 
local function _appendExt(f)
    return f:find('%.') and f or (f..".lua")
end
 
local function _removeExt(f)
    local dot = f:find('.', 1, true)
    return dot and f:sub(1, dot-1) or f
end
 
-- parse for module name when compiler exceptions occur
local function _shortsource(s, maxlength)
    local max = 60
    s, maxlength = s:sub(1, max), maxlength or 30
    max = 1 + s:len()
        
    local n, c
    for i = 1, max do
        n, c = i, s:sub(i, i)
        if not(c == ' ' or c == '\n') then
            break
        end
    end
    
    if n == max then return '' end
        
    local start = n    
    for i = start, max do
        c = s:sub(i, i)
        if not(c == '\n' or i >= start + maxlength) then
            n = i
        else break end
    end
        
    return s:sub(start, n)
end
 
-- TODO: when Codea allows optional tab execution,
-- we'll need to take into account added boilerplate line
-- at the top of the module when reporting errors
local function _traceback(minlevel)
    minlevel = minlevel or 2
    local t = {}
    for level = minlevel, math.huge do
        local info = debug.getinfo(level, "Sln")
        if not info then break end
        if info.what == "C" then
            insert(t, 'C function');
        else
            local name, desc = info.name, _shortsource(info.source)
            if desc == '' then desc = 'unknown' end
            desc = '[' .. desc .. ']'            
            if name then desc = desc .. ":" .. name end  
            local currentline = info.currentline
            if info.currentline == -1 then currentline = '?' end
            s = desc .. ":" .. currentline .. "\n"
            insert(t, s)
        end
    end
    
    return "\ntrace:\n" .. table.concat(t)
end
 
-- remove the block comment wrapper, and 
-- wrap the contents of a file with our boilerplate code
local function _wrap(s, p, t, header)
    -- TODO: present error on malformed long comment wrapper
    
    -- find the first occurrence of a long comment, so
    -- we can see how many = are in it to refine our search
    local b, e = s:find('--%[%=[%=]*%[')
    local oc = '--[[ ' .. p .. ':' .. t .. ' --]] '
    if e then
        -- error(format("\n\n%s\n%s:%s", "No long comment in", p,t))
        local ne = rep('[%=]', (e-b)-3)
        
        -- do end first
        b, e = s:find('--%]' .. ne .. '%]')
        e = s:find('\n', e, true)
        local cs = s:sub(b, e):gsub('%]', '%%]')
        s = s:gsub(cs, 'end')
        
        -- now do function header
        b, e = s:find('--%[' .. ne .. '%[')
        e = s:find('\n', e, true)
        
        -- wrap the source and return it
        cs = s:sub(b, e-1):gsub('%[', '%%[')
        return s:gsub(cs, oc..header)
    else
        return oc .. header .. s .. "\nend"
    end
end
 
-- check to see if a module has already been loaded;
-- if so, return it's data
local function _findLoaded(cpath, fallback)
    local spos = cpath:find(":", 1, true)
    
    if spos ~= nil then
        cpath = _appendExt(cpath)
        return _modules[cpath], _envs[cpath], _exports[cpath], true, cpath, cpath:sub(1, spos-1), cpath:sub(spos+1)
    else
        -- check running project first
        local file, cpath = cpath, _appendExt(_this .. ":" .. cpath)
        local mod = _modules[cpath]
        if mod ~= nil then
            return mod, _exports[cpath], false, cpath, _this, cpath:sub(#_this+2)
        end
        
        -- now check all of the projects in the search path
        if _path then
            local project
            for i = 1, #_path do
                project = _path[i]
                cpath = _appendExt(project .. ":" .. file)
                mod = _modules[cpath]
                if mod ~= nil then
                    return mod, _envs[cpath], _exports[cpath], false, cpath, project, cpath:sub(#project+2)
                end
            end
        end
        
        -- check fallback
        if fallback then
            cpath = _appendExt(fallback .. ":" .. file)
            mod = _modules[cpath]
            if mod ~= nil then
                return mod, _envs[cpath], _exports[cpath], false, cpath, fallback, cpath:sub(#fallback+2)
            end
        end
        
        -- module is not loaded
        return nil, nil, nil, false, nil, nil, _appendExt(file)
    end
end
 
-- search for a module's file in the search chain
local function _search(f, fallback)
    -- check running project first
    local file = fopen(_fspath(_this, f), "r")
    
    if file ~= nil then
        return _this, file
    end
    
    -- check search path
    if _path then
        local p = _this        
        for i = 1, #_path do
            p = _path[i]
            file = fopen(_fspath(p, f), "r")
            
            if file ~= nil then
                return p, file
            end
        end
    end
    
    -- check fallback
    if fallback then
        file = fopen(_fspath(fallback, f), "r")
        if file ~= nil then
            return fallback, file
        end
    end
end
 
-- load a module given a file, project name, file name, and module header
local function _readmodule(file, p, f, header,e)
    local s = file:read("*a")
    file:close()
    local tab = _removeExt(f)
    local chunk, e = load(_wrap(s, p, tab, header), tab, "t", e)
    
    if e then
        error(format("\n\n%s\n%s", e, _traceback(4)))
    end
    
    return chunk
end
 
-- forward declare for _include
local import
 
-- memoize overridden cinclude closures
-- since we only need one per owning project.
local _overrides = {}
 
-- provide syntactic sugar for cimport when overriding
-- search path to load from containing project. e.g.:
--     cinclude "SomeModule"
-- is the same as
--     cimport(__proj "SomeModule")
local function _override(prefix)
    local override = _overrides[prefix]
    
    if not override then
        override = function(modulename)
            return _import(prefix .. modulename)
        end
        _overrides[prefix] = override
    end
    
    return override
end
 
-- default module metatable/index
local _defaultMT = {__index = _G}
 
-- memoize __pathto closures, since we only need
-- one per owning project
local _pathto = {}
 
-- prepare sandboxed environment for loaded modules
local function _makeEnv(p, f, e)
    e = setmetatable({}, e and {__index = e} or _defaultMT)
    
    local prefix = p .. ":"
    local pathto = _pathto[prefix]
        
    if not pathto then
        pathto = function(f) return prefix .. f end
        _pathto[prefix] = pathto
    end
 
    return e, pathto, prefix
end
 
-- return a string listing the current project path
local function _pathString()
    local spath
    
    if _path and #_path > 0 then
        spath = "{"
        for i, v in ipairs(_path) do
            spath = spath .. v
            if i < #_path then
                spath = spath .. ", "
            end
        end
        return spath .. "}"
    end
    
    return "{none}"
end
 
-- keep track of modules that are currently loading,
-- so that we can detect dependency cycles
local _loading = {}
 
-- import a module. imported module is memoized so
-- successive imports do not have to re-load the module
-- each time. If nothing is returned, the module environment
-- itself will be imported (i.e. the module's _M table)
function _import(codeapath, fallback)
    local mod, env, exps, absolute, cpath, p, f = _findLoaded(codeapath)
    -- everything in loading is a reverse dependency of this module
    if mod == nil then
        local file
        if absolute then
            if p then
                file = fopen(_fspath(p, f), "r")
            end
        else
            p, file = _search(f, fallback)
            if p then cpath = p .. ":" .. f end
        end
        
        if not file then
            local spath = _pathString()
            error(format("Module not found: %s\n\nin search path:%s\n\nfallback:%s\n\n%s", codeapath,
                spath, fallback or "none", _traceback(3)))
        end
        
        if _loading[cpath] then
            error(format("circular dependency detected loading %s\n%s", cpath, _traceback(3)))
        end                

        _loading[cpath] = true
         local env, pathto, prefix = _makeEnv(p, f)
        local loaded
            loaded = _readmodule(file, p, f, _importHeader,env)()
        _tmpexports = {}
        _envs[cpath] = env  
        pushEnv(env)
        mod = loaded(env, p, f, pathto, _override(prefix)) or env
        _modules[cpath] = mod
        exps = _tmpexports
        _tmpexports = {}
        _loading[cpath] = nil
        popEnv()

        local cache = env[opt_cache]
        if cache ~= nil then
            env[opt_cache] = nil
            if cache == false then
                 if exps then
                    local e = currentEnv() or _G
                    for k,v in pairs(exps) do
                        e[k] = v
                    end
                end
                _modules[cpath] = nil    
                return mod
            end
        end
        _exports[cpath] = exps
    end
    if exps then
        local e = currentEnv() or _G
        for k,v in pairs(exps) do
            e[k] = v
        end
    end
    if not _rdependencies[cpath] then
        _rdependencies[cpath] = {}
    end
    for k,v in pairs(_loading) do
        _rdependencies[cpath][k] = true
    end
    return mod    
end
 
-- load a data module. if an environment is provided, it will
-- be the sandboxed module environment. if no environment
-- is provided, the global table will be exposed to the
-- module environment.
local function _load(codeapath, environment, fallback)
    if not fallback and type(environment) == "string" then
        fallback, environment = environment
    end
    
    local spos, p, f, cpath, file = codeapath:find(":", 1, true)
    
    if spos ~= nil then
        cpath = _appendExt(codeapath)
        p, f = cpath:sub(1, spos-1), cpath:sub(spos+1)
        file = fopen(_fspath(p, f), "r")
    else
        f = _appendExt(codeapath) 
        p, file = _search(f, fallback)
        if p then cpath = p .. ":" .. f end    
    end
    
    if not file then
        local spath = _pathString()
        error(format("Module not found: %s\n\nin search path:%s\n\nfallback:%s\n\n%s", codeapath,
            spath or "{none}", fallback or "none", _traceback(3)))
    end
        
    if _loading[cpath] then
        error(format("circular dependency detected loading %s\n%s", cpath, _traceback(3)))
    end                 
 
    _loading[cpath] = true            
    
    local loaded = _readmodule(file, p, f, _loadHeader)()
    local env, pathto = _makeEnv(p, f, environment)
    mod = setfenv(loaded, env)(p, f, pathto) or env

    _loading[cpath] = nil
    
    return mod
end
 
---------------------------
-- exports
---------------------------
    
-- import a source module; identical to cmodule.import
_G.cimport = _import
 
-- load a data module; identical to cmodule.load
_G.cload = _load    
    
-- cmodule utitlities
_G.cmodule = setmetatable({
 
    -- set/get the project path. the path may only be set once
    path = function(...)
        local narg = select("#", ...)
        
        -- return the current path if no params are specified
        if narg == 0 then
            -- return a copy of the path so it can't be modified
            return _path and {unpack(_path)} or nil
        end
        
        if _path then
            error("cmodule.path may only be set once")
        end
        _path = {...}
        local tabs,rm,main
        rm = {}
        for k,v in ipairs(_path) do
            main = fopen(_fspath(v, "Main.lua"), "r")
            if not main then
                    main = fopen(_fspath("Library " .. v, "Main.lua"), "r")
                if not main then
                    table.insert(rm,1,k)
                else
                    _path[k] = "Library " .. v
                end
            end
        end
        --[[
            tabs = listProjectTabs(v)
            if #tabs == 0 then
                tabs = listProjectTabs("Library " .. v)
                if #tabs == 0 then
                    table.insert(rm,1,k)
                else
                    _path[k] = "Library " .. v
                end
            end
        --]]
        for k,v in ipairs(rm) do
            table.remove(_path,v)
        end
    end,

    reset = function()
        _this,_path,_modules,_exports = nil,nil,{},{}
    end,
 
    -- return the name of the running project
    project = function() return _this end,

    save = function()
        return {_this,_path,_modules,_exports}
    end,

    restore = function(t)
        _this,_path,_modules,_exports = unpack(t)
    end,
    
    -- unload a loaded module
    -- params: module name or absolute module path
    unload = function(codeapath, fallback)
        local mod,_, _, cpath = _findLoaded(codeapath, fallback)
        if mod then
            _modules[cpath] = nil
        end
    end,
 
    -- params: module name or absolute module path
    -- returns: true if a module can be located and loaded; else false
    exists = function(codeapath, fallback)
        local spos = codeapath:find(":", 1, true)
        local absolute = (spos ~= nil)
        
        local p, f, cpath, file
        
        if absolute then
            cpath = _appendExt(codeapath)
            p, f = cpath:sub(1, spos-1), cpath:sub(spos+1)
            file = fopen(_fspath(p, f), "r")
        else
            f = _appendExt(codeapath) 
            p, file = _search(f, fallback)
            if p then cpath = p .. ":" .. f end    
        end
        
        if file then
            file:close()
            return true, cpath
        end
        
        return false
    end,
    
    -- params: none, module name, or absolute module path
    -- returns: if no params are specified, array of loaded modules;
    --          otherwise, module path if module is found, or nil if not found
    loaded = function(codeapath, fallback)
        if codeapath then
            local _,_, _,_, cpath = _findLoaded(codeapath, fallback)
            return cpath
        else
            local loaded = {}
            for k in pairs(_modules) do insert(loaded, k) end
            return loaded                
        end
    end,

    transfer = function()
        local g = Graph()
        for k,v in pairs(_modules) do
            g:addNode(k)
        end
        for k,v in pairs(_rdependencies) do
            for l,u in pairs(v) do
                g:addEdge(k,l)
            end
        end
        local s = g:sort()
        if s then
            local ns = {}
            local file
            for k,v in ipairs(s) do
                file = fopen(v.name, "r")
                table.insert(ns,v.name)
            end
            return ns
        end
    end,
    
    environment = function (codeapath, fallback)
        if codeapath then
            local _,env = _findLoaded(codeapath, fallback)
            return env
        end
    end,

    -- split an absolute path into separate project and file components;
    -- if relative path is used, currently running project name is appended
    -- params: absolute module path or module name in current project
    -- returns: project name, tab name
    resolve = function(cpath)
        cpath = _appendExt(cpath)        
        local i = cpath:find(":", 1, true)
    
        if i then
            return cpath:sub(1, i-1), cpath:sub(i+1), cpath
        end
    
        return _this, cpath, _this .. ":" .. cpath
    end,
    
    -- utility to export multiple variables to the global namespace
    -- params: table containing key/value pairs to be exported to _G
    gexport = function(exports)
        for k, v in pairs(exports) do
            _G[k] = v
        end
    end,        
    
    export = function(exports)
        for k,v in pairs(_tmpexports) do
            _tmpexports[k] = nil
        end
        for k, v in pairs(exports) do
            _tmpexports[k] = v
        end
    end,        
    
    -- by default, all modules loaded by cimport are cached.
    -- to disable caching for a module, add this to your module file:
    --     _M[cmodule.cache] = false
    cache = opt_cache,                
}, {
    -- params: project name.
    -- returns: cmodule.import, as a convenience.
    -- notes: this should be executed before any
    -- other code in your program.
    __call = function (_, thisProject)
        -- set currently running project name
        _this = thisProject
        
        -- return import to allow for a chained initialization/import,
        -- for example: cmodule "myProject" "setup"
        return _import
    end,
})
 
