local InsertService = game:GetService('InsertService')
local SS = game:GetService('ServerStorage')
local lib = SS:FindFirstChild('VarcoLib2') or Instance.new('Folder', SS)
lib.Name = 'VarcoLib2'
local out = {}
do
  local old = lib:FindFirstChild('Imp'); if old then old:Destroy() end
  local ok, m = pcall(function() return InsertService:LoadAsset(90053239335409) end)
  if ok then
    local c = m:GetChildren()[1]
    c.Name = 'Imp'; c:SetAttribute('AssetId', 90053239335409); c.Parent = lib; m:Destroy()
    local _, s = c:GetBoundingBox()
    table.insert(out, 'Imp ' .. tostring(s))
  else table.insert(out, 'Imp FAIL ' .. tostring(m)) end
end
do
  local old = lib:FindFirstChild('Goblin'); if old then old:Destroy() end
  local ok, m = pcall(function() return InsertService:LoadAsset(76390003832645) end)
  if ok then
    local c = m:GetChildren()[1]
    c.Name = 'Goblin'; c:SetAttribute('AssetId', 76390003832645); c.Parent = lib; m:Destroy()
    local _, s = c:GetBoundingBox()
    table.insert(out, 'Goblin ' .. tostring(s))
  else table.insert(out, 'Goblin FAIL ' .. tostring(m)) end
end
do
  local old = lib:FindFirstChild('Dragon'); if old then old:Destroy() end
  local ok, m = pcall(function() return InsertService:LoadAsset(120655135734214) end)
  if ok then
    local c = m:GetChildren()[1]
    c.Name = 'Dragon'; c:SetAttribute('AssetId', 120655135734214); c.Parent = lib; m:Destroy()
    local _, s = c:GetBoundingBox()
    table.insert(out, 'Dragon ' .. tostring(s))
  else table.insert(out, 'Dragon FAIL ' .. tostring(m)) end
end
do
  local old = lib:FindFirstChild('Mushroom'); if old then old:Destroy() end
  local ok, m = pcall(function() return InsertService:LoadAsset(88683486650808) end)
  if ok then
    local c = m:GetChildren()[1]
    c.Name = 'Mushroom'; c:SetAttribute('AssetId', 88683486650808); c.Parent = lib; m:Destroy()
    local _, s = c:GetBoundingBox()
    table.insert(out, 'Mushroom ' .. tostring(s))
  else table.insert(out, 'Mushroom FAIL ' .. tostring(m)) end
end
do
  local old = lib:FindFirstChild('Slime'); if old then old:Destroy() end
  local ok, m = pcall(function() return InsertService:LoadAsset(78866507200373) end)
  if ok then
    local c = m:GetChildren()[1]
    c.Name = 'Slime'; c:SetAttribute('AssetId', 78866507200373); c.Parent = lib; m:Destroy()
    local _, s = c:GetBoundingBox()
    table.insert(out, 'Slime ' .. tostring(s))
  else table.insert(out, 'Slime FAIL ' .. tostring(m)) end
end
do
  local old = lib:FindFirstChild('Cauldron'); if old then old:Destroy() end
  local ok, m = pcall(function() return InsertService:LoadAsset(106285278781244) end)
  if ok then
    local c = m:GetChildren()[1]
    c.Name = 'Cauldron'; c:SetAttribute('AssetId', 106285278781244); c.Parent = lib; m:Destroy()
    local _, s = c:GetBoundingBox()
    table.insert(out, 'Cauldron ' .. tostring(s))
  else table.insert(out, 'Cauldron FAIL ' .. tostring(m)) end
end
do
  local old = lib:FindFirstChild('PotionRed'); if old then old:Destroy() end
  local ok, m = pcall(function() return InsertService:LoadAsset(118895096143559) end)
  if ok then
    local c = m:GetChildren()[1]
    c.Name = 'PotionRed'; c:SetAttribute('AssetId', 118895096143559); c.Parent = lib; m:Destroy()
    local _, s = c:GetBoundingBox()
    table.insert(out, 'PotionRed ' .. tostring(s))
  else table.insert(out, 'PotionRed FAIL ' .. tostring(m)) end
end
do
  local old = lib:FindFirstChild('PotionGreen'); if old then old:Destroy() end
  local ok, m = pcall(function() return InsertService:LoadAsset(105962866042484) end)
  if ok then
    local c = m:GetChildren()[1]
    c.Name = 'PotionGreen'; c:SetAttribute('AssetId', 105962866042484); c.Parent = lib; m:Destroy()
    local _, s = c:GetBoundingBox()
    table.insert(out, 'PotionGreen ' .. tostring(s))
  else table.insert(out, 'PotionGreen FAIL ' .. tostring(m)) end
end
do
  local old = lib:FindFirstChild('PotionBlue'); if old then old:Destroy() end
  local ok, m = pcall(function() return InsertService:LoadAsset(109206406661045) end)
  if ok then
    local c = m:GetChildren()[1]
    c.Name = 'PotionBlue'; c:SetAttribute('AssetId', 109206406661045); c.Parent = lib; m:Destroy()
    local _, s = c:GetBoundingBox()
    table.insert(out, 'PotionBlue ' .. tostring(s))
  else table.insert(out, 'PotionBlue FAIL ' .. tostring(m)) end
end
do
  local old = lib:FindFirstChild('HerbShelf'); if old then old:Destroy() end
  local ok, m = pcall(function() return InsertService:LoadAsset(77614891478054) end)
  if ok then
    local c = m:GetChildren()[1]
    c.Name = 'HerbShelf'; c:SetAttribute('AssetId', 77614891478054); c.Parent = lib; m:Destroy()
    local _, s = c:GetBoundingBox()
    table.insert(out, 'HerbShelf ' .. tostring(s))
  else table.insert(out, 'HerbShelf FAIL ' .. tostring(m)) end
end
do
  local old = lib:FindFirstChild('Crystal'); if old then old:Destroy() end
  local ok, m = pcall(function() return InsertService:LoadAsset(106259107109450) end)
  if ok then
    local c = m:GetChildren()[1]
    c.Name = 'Crystal'; c:SetAttribute('AssetId', 106259107109450); c.Parent = lib; m:Destroy()
    local _, s = c:GetBoundingBox()
    table.insert(out, 'Crystal ' .. tostring(s))
  else table.insert(out, 'Crystal FAIL ' .. tostring(m)) end
end
return table.concat(out, '\n')
