--local currentFolder = "/Users/xxx/Documents/quick-cocos2d-x/projects/xxoo/res"
require "lfs"

local  currentFolder = device.writablePath;

local function hex(s)
s=string.gsub(s,"(.)",function (x) return string.format("%02X",string.byte(x)) end)
return s
end
local function readFile(path)
    local file = io.open(path, "rb")
    if file then
        local content = file:read("*all")
        io.close(file)
        return content
    end
    return nil
end

local function findindir(path, wefind, dir_table, r_table, intofolder)
    print(path)
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." and file ~= ".DS_Store" and file ~= "flist" and file ~= "launcher.zip" then
            local f = path.."/"..file
            
            local attr = lfs.attributes (f)
            assert (type(attr) == "table")
            if attr.mode == "directory" and intofolder then
                table.insert(dir_table, f)
                findindir(f, wefind, dir_table, r_table, intofolder)
            else
                table.insert(r_table, {name = f, size = attr.size})
            end  
        end
    end
end
    MakeFileList = {}
    function MakeFileList:run(path)
        
        local dir_table = {}
        local input_table = {}
        findindir(currentFolder..path, ".", dir_table, input_table, true)
        local pthlen = string.len(currentFolder..path)+2
        local buf = "local flist = {\n"
        buf = buf.."\tappVersion = 1,\n"
        buf = buf.."\tversion = \"1.0.2\",\n"
        buf = buf.."\tdirPaths = {\n"
        for i,v in ipairs(dir_table) do
            --print(i,v)
            local fn = string.sub(v,pthlen)
            buf = buf.."\t\t{name = \""..fn.."\"},\n"
        end
        buf = buf.."\t},\n"
        buf = buf.."\tfileInfoList = {\n"
        for i,v in ipairs(input_table) do
            --print(i,v)
            local fn = string.sub(v.name, pthlen)
            buf = buf.."\t\t{name = \""..fn.."\", code = \""
            local data=readFile(v.name)
            local ms = crypto.md5(hex(data or "")) or ""
            buf = buf..ms.."\", size = ".. v.size .."},\n"
        end
        buf = buf.."\t},\n"
        buf = buf.."}\n\n"
        buf = buf.."return flist"
        io.writefile(currentFolder..path.."/flist", buf)
    end
    return MakeFileList