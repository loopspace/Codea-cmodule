--The name of the project must match your Codea project name if dependencies are used. 
--Project: cmodule
--Version: v0.1.0.1
--Dependencies:
--Comments:

-- Main
 
-- see cmodule_tests at: https://gist.github.com/apendley/5594141
-- for very basic examples of cmodule usage;
-- better tests are on the way.
 
    cmodule "CModule"
 cmodule.path("Base","UI", "Games and Puzzles", "Utilities")

function setup()
    -- cmodule.path("Base","UI", "Games and Puzzles", "Utilities")
    t = cimport "Touch"()
    UTF8 = cimport "utf8"
    cimport "ColourNames"
    if cmodule.loaded "Game" then
        print("Game loaded")
    end
    cimport "Coordinates"
    print(t)
    print("Screen", Screen)
    s = "]"
    print(s,s:gsub("%]","%%]"))
    print(s)
    cimport "Game"
    print(UTF8(2464))
    UTF8 = cimport "utf8"
    print(UTF8(2464))
    cimport "Font"
    local te = cmodule.environment "Font"
    for k,v in pairs(te) do
        print(k,v)
    end
    ui = cimport "UI"(t)
end