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

require "lfs"

local function findindir (path, wefind, r_table, intofolder) 
    for file in lfs.dir(path) do 
        if file ~= "." and file ~= ".." then 
            local f = path.."/"..file 
            if string.find(f, wefind) ~= nil then 
                table.insert(r_table, f) 
            end 
        end 
    end
end

    MakeFileList = {}

    function MakeFileList:run(path)
        currentFolder = device.writablePath..path
        local input_table = {} 
        findindir(currentFolder, ".", input_table, true)
        local pthlen = string.len(currentFolder)+2
        local buf = "stage = {\n"
        for i,v in ipairs(input_table) do
            print(i,v)
            local fn = string.sub(v,pthlen)
            buf = buf.."\t{name=\""..fn.."\", code=\""
            local data=readFile(v)
            local ms = crypto.md5(hex(data or "")) or ""
            buf = buf..ms.."\", act=nil},\n"
        end
        buf = buf.."}"
         io.writefile(device.writablePath.."flist.txt", buf)
    end

    return MakeFileList