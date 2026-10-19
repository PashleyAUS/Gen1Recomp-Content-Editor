local root=assert(os.getenv("EDITOR_TEST_ROOT")):gsub("\\","/")
package.path=root.."/tools/content-editor/?.lua;"..package.path
local assets,sources={},{}
package.loaded.ModIO={readText=function(p) return assets[p] end,ensureDirectory=function() return true end,writeText=function(p,v) assets[p]=v;return true end}
local pixels
package.loaded.LayeredMap={sourceDescriptor=function(S,id) return sources[id] end,
  addTileSource=function(project,id,path,w,h) local s={id=id,image=path,columns=w/16,count=w*h/256};sources[id]=s;return s end,
  drawSourceTile=function(S,src,tile,x,y)
    local img=src.image and love.graphics.newImage(love.filesystem.newFileData(assets[S.path.."/"..src.image],"tile.png")) or pixels
    local q=love.graphics.newQuad(tile%src.columns*16,math.floor(tile/src.columns)*16,16,16,img:getDimensions())
    love.graphics.draw(img,q,x,y);return true
  end}
love.errorhandler=function(err) print(err);love.event.quit(1);return function() return 1 end end
function love.load()
  love.graphics.setDefaultFilter("nearest","nearest")
  local data=love.image.newImageData(32,16)
  data:mapPixel(function(x,y) return x/31,y/15,0,1 end);pixels=love.graphics.newImage(data)
  sources.original={id="original",columns=2}
  local T=require("TileRotation")
  for _,axis in ipairs({"horizontal","vertical"}) do
    local S={path="test",project={},builderSourceId="original",builderStamp={source="original",cells={{dx=0,dy=0,tile=0},{dx=1,dy=0,tile=1}}}}
    local src=T.mirror(S,axis)
    assert(src.columns==2 and src.count==2)
    local out=love.image.newImageData(love.filesystem.newFileData(assets["test/"..src.image],"tile.png"))
    for y=0,15 do for x=0,31 do
      local r,g=data:getPixel(x,y)
      local rr,gg=out:getPixel(axis=="horizontal" and 31-x or x,axis=="vertical" and 15-y or y)
      assert(math.abs(r-rr)<.01 and math.abs(g-gg)<.01,"Mirror pixels differ: "..axis)
    end end
    assert(S.builderStamp.cells[1].dx==(axis=="horizontal" and 1 or 0))
  end
  print("Tile mirror pixel checks passed")
  love.event.quit(0)
end
