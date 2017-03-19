Graph = class()

function Graph:init()
    self.nodes = {}
    self.nodeNames = {}
    self.num = 0
end

function Graph:addNode(t)
    local name,edges
    if type(t) == "string" then
        name = t
    elseif type(t) == table then
        name = t.name
        edges = t.edges
    else
        name = "Node" .. self.num
    end
    self.num = self.num + 1
    local n = {
        name = name,
        index = self.num,
        edges = {}
    }
    table.insert(self.nodes,n)
    self.nodeNames[name] = self.num
    if edges then
        for k,v in ipairs(edges) do
            self:addEdge(n,v)
        end
    end
    return n
end

function Graph:addEdge(a,b)
    a = self:getNode(a)
    b = self:getNode(b)
    if not a or not b then
        return
    end
    table.insert(a.edges,b)
end

function Graph:getNode(a)
    if type(a) == "number" then
        a = self.nodes[a]
    elseif type(a) == "string" then
        a = self.nodes[self.nodeNames[a]]
    end
    return a
end

local visit

function visit(n,f)
    if n.mark then
        return true
    end
    if n.tmark then
        return false
    end
    n.tmark = true
    for k,v in ipairs(n.edges) do
        if not visit(v,f) then
            return false
        end
    end
    n.tmark = false
    n.mark = true
    f(n)
    return true
end

function Graph:depthSearch(f)
    self:clearMarks()
    local dag = true
    for k,v in ipairs(self.nodes) do
        if not visit(v,f) then
            dag = false
            break
        end
    end
    return dag
end

function Graph:isAcyclic()
    return self:depthSearch(function() end)
end

function Graph:clearMarks()
    for k,v in ipairs(self.nodes) do
        v.mark = false
        v.tmark = false
    end
end

function Graph:sort()
    local rs = {}
    if self:depthSearch(function(n) table.insert(rs,n) end) then
        local s = {}
        for k=1,self.num do
            s[k] = rs[self.num-k+1]
        end
        return s
    else
        return false
    end
end
