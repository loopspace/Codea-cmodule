--[====[
 
What is cmodule?
================
 
cmodule is a package-based source loader designed for Codea.
 
 
Why use cmodule?
================
 
Codea's built in source execution environment is fantastic for getting simple projects up and running quickly.  However, once a project becomes larger in scope, it can get difficult to manage the global namespace, and to reason about the dependency graph of your project. This situation can be a hotbed for difficult to diagnose bugs. Additionally, all tabs in a Codea project are loaded and executed by default. This can cause memory to fill up unnecessarily when some of the tabs may be used infrequently (such as level data in a game). These problems can be further exascerbated when collaborating with others. cmodule attempts to address these issues, by providing a modular system for loading and executing source code. Every module declares it's dependencies explicitly by calling cmodule's cimport() and cload() functions, which eliminates the visibility of code that is not used by a module, thus helping to reduce bugs considerably. cmodule also allows for sandboxed loading and execution of tabs that are intended to be used as data files, allowing you to fully customize the format of your application data, as well as only having the data resident in memory when it is in use.
 
One side effect of the addressing the issues stated above is that (given wide enough adoption) code using a module system tends to be easier to share. Packaging libraries and middleware for use by others becomes much simpler.
 
 
How does cmodule work?
======================
 
cmodule allows you to load and execute any tab from any project currently resident in Codea on your device, without using Codea's project dependency feature. In the current pre-release form, it exploits a feature of Lua's block commenting and a bug in Codea's syntax highlighting to convince Codea not to execute the code in every tab in a project. It works by wrapping the contents of every tab that cmodule loads in a Lua block comment. Fortunately, Lua's block commenting feature is very flexible, and allows for nested block comments, so that you can still use block comments freely in your code. The form of block comment you are probably most familiar with looks like this:
 
    --[[ this is a block comment --]]
    
Incidentally, that form can be expanded like so:
 
    --[=[ this is a block comment --]=]
    
You can actually use as many = as you like:
    --[=====[ this is a block comment --]=====]
 
By combining these forms, you can nest block comments:
 
    --[=[ 
        This is a block comment
        
        --[[
            This is a nested block comment
        --]]
    --]=]
    
cmodule is agnostic to which form you use to wrap your module's contents, so you may use whichever you like. I tend to prefer using two ==, like so:
    --[==[
        module contents here
    --]==]
    
If you are reading this in Codea's text editor, you've probably already noticed the second exploit: Codea does not properly highlight block comments, so you still get the benefits of syntax highlighting when authoring your modules in Codea.
 
** Please note that this workaround will not be necessary for the final release. On Codea's feature tracker is a feature that allows for optional tab execution, which directly addresses the need for this workaround. In a not-entirely-coincidental time frame, cmodule should reach 1.0 **
 
When the end programmer calls cimport, cmodule attempts to load a module matching either a) an absolute path to a module, such as "MyProjectName:MyModuleName", or a relative path to a module, such as "MyModuleName".
 
If an absolute path is specified, the module at that path will be loaded, executed, and it's results (usually whatever the module returns) are cached for future reference. As such, subsequent calls to cimport using the same module path/name will not need to re-load and execute the module again, since the cached result exists. If a module is not found at an absolute path, a "module not found" error will be raised.
 
If a relative path is specified, cmodule will first attempt to load the module from the currently running project. If the module is not found, cmodule then attempts to find the module in any projects contained in the search path. If a module is still not found, a "module not found" error is raised (there is one exception to this, discussed later in the "fallbacks" section).
 
cload is a variant of cimport that is intended primarily for loading data modules in an optionally sandboxed environment. It follows the same module search procedure as cimport, though modules loaded by cload are not cached; every call to cload() with the same module path/name will result in the module being loaded and executed each time.
 
 
Getting started
===============
 
You can begin using cmodule in a few simple steps:
 
1. Download the cmodule source into it's own Codea project. Preferably, for compatibility with others, name the project "cmodule".
 
2. In your own project, include the cmodule project as a project dependency.
 
3. Either at the top of your Main tab, or at the beginning of setup, include:
        cmodule "<project name>"
   where <project name> is the name of your project as Codea knows it.
 
4. (optional) Specify the module search path for your project:
        cmodule.path("SomeProject", "SomeOtherProject", <etc>)
        
5. Start loading modules! Use cimport() to load source modules, and cload() to load data modules. Note that modules loaded by cmodule must follow the format outlined in the "How does cmodule work?" section.
 
Note that it is possible to load cmodule modules even if all of the modules in your project do not adhere to the cmodule specification. You may still take advantage of Codea's auto loading/execution to export code to the global namespace (that is, you may use a mix of cmodule and non-cmodule code together, with care).    
 
 
fallbacks
=========
 
Fallbacks provide a mechanism for specifying that you would like a project added to the end of the search path at the time of calling cimport/cload. When a fallback is specified, if a module is not found in the running project, or in the project's search path, cmodule will attempt one last time to load it from the fallback project. Commonly, this is useful for specifying that you would like to load a module from the calling module's containing project, but only if that module is not found first in the running project or a project in the search path.
 
 
cmodule API
===========
 
cmodule
-------
    description:
        Initialize cmodule
    
    usage:
        cmodule(projectName)
        
    params:
        projectName: string containing the name of the currently running project, as Codea knows it.
        
    returns:
        cimport, for chaining cmodule initialization with an immediate module import.
        
path
----
    description:
        Specify a project's module search path, or get the current project's search path.
 
    usage:
        cmodule.path([first [,second] [,third] ... ])
    
    params:
        none, or a variable list of strings containing the names of projects to include in the search path.
        
    returns:
        if zero parameters specified, a table of strings containing project names in the search path;
        othersize, nil.
 
project
-------
    description:
        returns the name of the currently running project.
    
    usage:
        cmodule.project()
 
 
cimport
-------
    description:
        loads and executes, and caches a source module
 
    usage:
        cimport("<module path or name>" [,fallback])
    
    params: the first param is either an absolute module path ("MyProjectName:MyModuleName") or
            a relative module path ("MyModuleName").
            
            fallback: if specified, cimport will attempt to load a module from a relative path using
                      the fallback project, if the module is not first found either in a) the running project,
                      or b) a project in the search path.
    
    returns: upon success, returns result of module execution.
             upon failure, throws a "module not found" error
 
cload
-----
    description:
        loads and executes an optionally sandboxed data file
 
    usage:
        cload("<module path or name>" [,environment] [,fallback])
    
    params: the first param is either an absolute module path ("MyProjectName:MyModuleName") or
            a relative module path ("MyModuleName").
            
            environment: a table; if specified, cimport will use execute the module using the table
                         as it's running environment. Use this to enable sandboxed module execution.
                         if no environment is specified, the global environment (_G) will be exposed.
            
            fallback: if specified, cload will attempt to load a module from a relative path using
                      the fallback project, if the module is not first found either in a) the running project,
                      or b) a project in the search path.
    
    returns: upon success, returns result of module execution.
             upon failure, throws a "module not found" error
 
loaded
------
    description: returns a list of currently loaded modules, or returns the path of a module
                 if it is loaded.
                
    usage:
        cmodule.loaded("<module path or name>" [,fallback])
        
    params:
        zero, or:
        first and fallback params follow the same rules as cimport/cload for locating modules.
        
    returns:
        if zero arguments are specified, a table containing a list of strings 
        containing the absolute path of each loaded module.
        otherwise, the module's absolute path if module is loaded, or nil if not.
 
exists
------
    description: identify whether a module exists given a module path or name.
    
    usage:
        cmodule.exists("<module path or name>" [,fallback])
        
    params:
        first and fallback params follow the same rules as cimport/cload for locating modules.        
        
    returns:
        if module exists, true and the absolute path to the module.
        otherwise, false
 
unload
------
    description: unload a loaded module
    
    usage:
        cmodule.unload("<module path or name>" [,fallback])
        
    params:
        first and fallback params follow the same rules as cimport/cload for locating modules.        
        
resolve
-------
    description: get the separated components of an absolute path and the fully qualified path
                 or the components of a path to the currently running project        
                
    usage:
         cmodule.resolve("<module path or name>")
        
    params: absolute path to module, or name of module in currently running project.
    
    returns: full path to specified module
 
gexport
-------
    description: export multiple objects to the global namespace
    
    usage:
        cmodule.gexport(map)
 
    params:
        map: a table containing key value pairs to map to the global namespace.
 
 
 
The module environment
======================
Every module it's loaded with it's own environment. The module environment provides additional API to modules loaded with cimport and cload.
 
 
__proj, __file
--------------
 
Every module contains 2 variables to access the owning project's name, and the module's name. For example, inside of a module located at "Foo:Bar", __proj will contain "Foo", and __file will contain "Bar".
 
 
__pathto
--------
 
As a convenience, each module is also provided with a helper function, __pathto. __pathto accepts a module name as it's only parameter, and returns a cmodule path. For example, in module "Foo:Bar", consider:
    
    local path = __pathto(__file)
 
Upon execution, path will contain "Foo:Bar". You can also use __pathto to obtain the path to another module contained in the same project. Again, in module "Foo:Bar", consider:
 
    local path = __pathto("MyModule")
    
    
Upon execution, path will contain "Foo:MyModule". Combined with cimport, you may specify that you explicitly want to load a module from the same project, without having to literally use the project's name. Again, in module "Foo:Bar", consider:
 
    local MyModule = cimport(__pathto "MyModule")
    
Upon execution, MyModule will contain the result of importing "Foo:MyModule". This usefulness of this becomes especially apparent when you duplicate/rename a project: if you had to use a string literal to specify the owning project's name, you'd have to update every single cimport() call that did so! Using this facility, this is not a problem.
 
 
cinclude
--------
 
Because loading a module from the same project is common, cmodule provides each module with a bit of syntactic sugar for doing so, in the form of an alternative to cimport: cinclude.
 
cinclude simply takes the name of a module in the same project:
 
    local MyModule = cinclude "MyModule"
 
is the same as
 
    local MyModule = cimport(__pathto "MyModule")
    
 
 
_M: the environment table
-----------------------------------
Every module also has an implicit global environment. That is to say, within a module, _G is not the global enviroment. Instead, there is _M. Any implicit assignments to the global environment will go to the _M table, rather than _G. Consider:
 
    myVariable = 10
    
Upon execution, _M.myVariable will contain the value 10, *not* _G.myVariable.
 
 
Since every module still has access to the global table, it is still possible to access it with _G. For example, to write to the global table:
 
    _G.myVariable = 10
 
You don't however need to prefix your variable if you are *reading* from the global table.
 
    print(myVariable) -- prints 10
    
A variable in _G with the same name as a variable in _M will be overshadowed:
 
    _G.myVariable = 10
    print(myVariable) -- prints 10
    _M.myVariable = 20    
    print(myVariable) -- prints 20
    print(_G.myVariable) -- prints 10
 
 
A nice benefit of this is that you cannot accidentally import variables to the global environment if you forget to declare a variable as local. They will be placed in the module's environment, or _M table, instead. In the next section we'll see a technique for writing module code that allows the _M table to be used as the module's result.
 
exporting from a module
-----------------------
 
Modules have 2 means to "export" their result. That is, when cimport/cload is called with a module path, a module typically exports a value that is then returned from cimport/cload.
 
    Method 1: explicit export via return
    ------------------------------------
    Since a module is essentially just a Lua function, it can return values like any other Lua function.
    cmodule supports returning a single value from a module. That value may be any non-nil Lua type, such
    as a tables, functions, coroutines, numbers, etc. If nil as returned, the effect is the same as
    Method 2 below.
    
    Method 2: implicit export
    -------------------------
    If a module chooses to return nil, or returns nothing at all (which is the same as returning nil),
    cimport/cload will return the module's _M table. Therefore, anything assigned to the _M table will
    be accessible via the table returned from cimport/cload. IMPORT SECURITY NOTE: Due to the way cmodule
    sandboxes modules, the global environment can be accessed via an exported module environment:
    
        -- the "Module" module uses method 2 to export it's values
        local Module = cimport("Module")
        Module._G.whatever = 10
    
    Be aware of this when creating your sandboxes for loading data using cload, since it allows for the 
    sandbox to be broken. When in doubt, explicitly return your exports from any modules that you are exposing
    in your sandbox (using method 1).
 
 
module caching
--------------
 
By default, cimport caches all modules that are loaded successfully, so that subsequent calls to cimport with the same module path/name will simply return the previously cached version. Sometimes this is not desireable; sometimes you want to ensure that a module is compiled and executed each time it is imported. A module may specify that it does not wish to be cached by including this line of code somewhere in the module's contents:
 
    _M[cimport.cache] = false
 
 
tips and tricks
===============
 
explicitly loading from common project vs. implicit search
-------------------------------------------------------------
 
Loading a module from the same containing project is a common occurrence. Typically, there are 2 ways to do this, each with it own's strengths:
 
1) use cinclude("Module") or cimport(__proj "Module") to load explicitly from containing project. Since this method generates an absolute path that is passed to cimport, *only* this path is considered as a candidate from which we should load the module. If module is not found in containing project, a "module not found" error will be thrown.
 
2) use cimport("Module", __proj) to search for module in running project and then search path *before* checking the containing project. Using this form allows you to write library code with overrideable behavior by client code.
 
Generally speaking, use 1) when a) you are sure you don't need to allow overrides for a module, and b) when a piece of code that allowed overriding before as a debugging mechanism has become mature enough to use absolute paths instead.
 
Use 2) when to do things like a) read library-specific config files from the running project, b) debug library modules by using the search path to override them, and c) I'm sure there's other reasons, you get the idea.
 
 
 
--]====]

