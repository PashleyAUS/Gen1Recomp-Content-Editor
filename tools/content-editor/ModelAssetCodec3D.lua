-- Data-only texture codec shared with exported mods.
local M={}
local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function M.encode(data)
  local out={}
  for i=1,#data,3 do
    local a,b,c=data:byte(i,i+2);local n=a*65536+(b or 0)*256+(c or 0)
    out[#out+1]=alphabet:sub(math.floor(n/262144)%64+1,math.floor(n/262144)%64+1)
      ..alphabet:sub(math.floor(n/4096)%64+1,math.floor(n/4096)%64+1)
      ..(b and alphabet:sub(math.floor(n/64)%64+1,math.floor(n/64)%64+1) or '=')
      ..(c and alphabet:sub(n%64+1,n%64+1) or '=')
  end
  return table.concat(out)
end
function M.decode(data)
  local out,n,bits={},0,0
  for c in data:gmatch('.') do
    if c~='=' and not c:match('%s') then
      local p=alphabet:find(c,1,true);assert(p,'Invalid base64 asset')
      n=n*64+p-1;bits=bits+6
      if bits>=8 then bits=bits-8;out[#out+1]=string.char(math.floor(n/2^bits));n=n%2^bits end
    end
  end
  return table.concat(out)
end
return M
