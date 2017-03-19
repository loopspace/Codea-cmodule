--[[

v0.1.0.1: (20/11-13, Andrew Stacey) Added a local version of cmodule.gexport which exports only into the environment of the calling code.  This avoids _G getting populated when a module needs to load auxiliary code.
 
v0.1.0: (5/21/2013)
    * added search path for locating relative module paths; search path can be
      set/inspected using cmodule.path(); pass no args for a list of projects in the path,
      or pass a variable list of projects, i.e. cmodule.path("project1", "project2", "project3").
      search path may only be set once. module search is executed in the order the projects
      are passed to cmodule.path.
    * added optional fallback project param to cimport/cload and cmodule.loaded/exists/unload;
      if a module is not found in the running project or in the search path, an attempt will
      be made to load from the fallback project if specified.
    * __pathto no longer returns fully qualified path to current module when no
      module name is specified; use __pathto(__file) instead.
    * no longer generating module closures for cload; use cload(__proj "MyModule") instead.
    * renamed overridden module cimport to cinclude; cinclude only takes a module
      name, not an absolute path; it is intended for loading from the containing project
      only; it is syntactic sugar for cimport(__pathto "MyModule")
    * now memoizing module cinclude/__pathto closures, which can reduce memory
      footprint considerably, and speed up loading/importing as well by not having
      to create 2 closures per model per owning project (now it's 2 closures per owning project)
    * removed redundant cmodule.import and cmodule.load. use cimport/cload instead.
 
v0.0.9: (5/17/2013):
    * removed cmodule.null. it is no longer necessary since module 
      module returns are no longer weak referenced, and all modules
      loaded with cimport are kept alive unless explicitly unloaded.
    * replaced cmodule.nocache with cmodule.cache; to achieve the same effect, 
      put this line of code in your module file: _M[cmodule.cache] = false
 
v0.0.8 (5/17/2013):
    * cmodule now keeps strong references to module return values
    * added API cmodule.unload() to unload a loaded module.
 
v0.0.7 (5/17/2013):
    * cimport/cload now only return 1 value, the value returned from the loaded module
    * added cmodule.resolve, which returns the project and file names for the given path
      if it is valid, nil otherwise.
 
v0.0.6 (5/17/2013):
    * cmodule.loaded now auto-applies the .lua extension if no extension is specified.
    * cmodule.loaded auto pre-pends the running project name if no project is specified
 
v0.0.5 (5/16/2013):
    * fixed bug from 0.0.4 where cmodule would not return nil for newly loaded
      modules that return cmodule.null
    * added function cmodule.gexport, that accepts a table of key value pairs
      that are batch exported to the global environment
    * add value cmodule.nocache that can be returned from a module to indicate
    * that cmodule should not cache the module (useful for running once-off scripts)
 
v0.0.4 (5/15/2013):
    * added unique null type, accessible via cmodule.null
    * cimport will now return nil for modules that return cmodule.null
 
--]]
