-- ---------------------------------------------------------------------------
--  Trading 212 account value skin - auth header, parsing and day change.
--
--  Entry points (called from Portfolio.ini via !CommandMeasure):
--    OnData()       - an account/summary response arrived
--    OnError(kind)  - WebParser could not connect / could not parse
--    Refresh()      - user asked for an immediate refresh
--
--  Rainmeter ships Lua 5.1, so no bit operators / goto / \u escapes here.
-- ---------------------------------------------------------------------------

-- Rainmeter cannot read UTF-8 .lua files, so this script stays pure ASCII.
-- Non-ASCII symbols are variables holding character references in
-- Variables.inc (#Euro#, #Pound#), resolved by the String meters, which have
-- DynamicVariables=1. Any currency not listed is shown as its ISO code.
local CURRENCY_SYMBOLS = {
  EUR = '#Euro#',
  GBP = '#Pound#',
  USD = '$',
}

-- Set from the account's currency on each response, or from the
-- CurrencySymbol setting when that is filled in.
local currencySymbol = ''

local paths = {}
local minInterval = 15

local baselineDate, baselineValue
local lastValue
local lastFetch = 0
local status, statusDetail = 'init', ''

-- --- helpers ---------------------------------------------------------------

local function var(name, default)
  local value = SKIN:GetVariable(name)
  if value == nil or value == '' then return default end
  return value
end

local function numVar(name, default)
  return tonumber(var(name, nil)) or default
end

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function b64char(n)
  return B64:sub(n + 1, n + 1)
end

-- Lua 5.1 has no bit operators, so the 24-bit groups are split arithmetically.
local function base64(s)
  local out = {}
  for i = 1, #s, 3 do
    local a, b, c = s:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    out[#out + 1] = b64char(math.floor(n / 262144) % 64)
      .. b64char(math.floor(n / 4096) % 64)
      .. (b and b64char(math.floor(n / 64) % 64) or '=')
      .. (c and b64char(n % 64) or '=')
  end
  return table.concat(out)
end

-- Reads a JSON number by key name, independent of field order.
local function jsonNumber(body, key)
  local raw = body:match('"' .. key .. '"%s*:%s*(%-?%d+%.?%d*[eE]?[%+%-]?%d*)')
  return tonumber(raw)
end

local function formatAmount(n)
  local sign = n < 0 and '-' or ''
  local text = string.format('%.2f', math.abs(n))
  local int, dec = text:match('^(%d+)%.(%d+)$')
  if not int then return sign .. text end
  int = int:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
  return sign .. int .. '.' .. dec
end

local function setVariable(name, value)
  SKIN:Bang('!SetVariable', name, value)
end

-- --- day baseline ----------------------------------------------------------

local function loadBaseline()
  local file = io.open(paths.baseline, 'r')
  if not file then return end
  local content = file:read('*a')
  file:close()
  baselineDate = content:match('Date%s*=%s*([%d%-]+)')
  baselineValue = tonumber(content:match('Baseline%s*=%s*(%-?[%d%.]+)'))
end

local function saveBaseline()
  local file = io.open(paths.baseline, 'w')
  if not file then
    print('Trading212: cannot write ' .. paths.baseline)
    return
  end
  file:write('Date=', baselineDate or '', '\n')
  file:write('Baseline=', string.format('%.2f', baselineValue or 0), '\n')
  file:close()
end

-- Captured on the first successful reading of each local day. If the PC was
-- off at midnight this is that day's first reading, not the previous close.
local function updateBaseline(value)
  local today = os.date('%Y-%m-%d')
  if baselineDate ~= today or baselineValue == nil then
    baselineDate = today
    baselineValue = value
    saveBaseline()
  end
end

-- --- rendering -------------------------------------------------------------

local function render()
  if lastValue then
    setVariable('TotalText', currencySymbol .. formatAmount(lastValue))
  end

  if status == 'ok' then
    if baselineValue and baselineValue ~= 0 and baselineDate == os.date('%Y-%m-%d') then
      local change = lastValue - baselineValue
      local percent = change / math.abs(baselineValue) * 100
      local sign = change >= 0 and '+' or '-'
      setVariable('ChangeText', string.format('%s%s%s   %s%.2f%% today',
        sign, currencySymbol, formatAmount(math.abs(change)), sign, math.abs(percent)))
      if change > 0.005 then
        setVariable('ChangeColor', var('ColorUp', '76,201,133,255'))
      elseif change < -0.005 then
        setVariable('ChangeColor', var('ColorDown', '232,93,93,255'))
      else
        setVariable('ChangeColor', var('ColorFlat', '138,146,158,255'))
      end
    else
      setVariable('ChangeText', 'Baseline set for today')
      setVariable('ChangeColor', var('ColorFlat', '138,146,158,255'))
    end
    setVariable('StatusText', statusDetail ~= '' and statusDetail or ('Updated ' .. os.date('%H:%M')))
    setVariable('StatusColor', statusDetail ~= '' and var('ColorError', '232,155,93,255')
      or var('ColorTextDim', '138,146,158,255'))

  elseif status == 'nokey' then
    setVariable('TotalText', '--')
    setVariable('ChangeText', 'Right-click > Custom skin actions')
    setVariable('ChangeColor', var('ColorFlat', '138,146,158,255'))
    setVariable('StatusText', statusDetail)
    setVariable('StatusColor', var('ColorError', '232,155,93,255'))

  elseif status == 'error' then
    -- The last good value stays on screen (set above).
    setVariable('StatusText', statusDetail)
    setVariable('StatusColor', var('ColorError', '232,155,93,255'))
  end

  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

-- --- entry points ----------------------------------------------------------

function Initialize()
  paths.baseline = SKIN:ReplaceVariables('#@#') .. 'State\\DayBaseline.inc'
  paths.settings = SKIN:ReplaceVariables('#@#') .. 'Settings.inc'
  -- account/summary allows 1 request per 5 seconds.
  minInterval = math.max(5, numVar('RefreshSeconds', 60) / 4)

  loadBaseline()

  local key, secret = var('ApiKey', ''), var('ApiSecret', '')
  if key == '' or secret == '' then
    -- MeasureSummary starts disabled, so no unauthenticated requests go out.
    status, statusDetail = 'nokey', 'No API key / secret set'
  else
    SKIN:Bang('!SetOption', 'MeasureSummary', 'Header',
      'Authorization: Basic ' .. base64(key .. ':' .. secret))
    SKIN:Bang('!EnableMeasure', 'MeasureSummary')
    SKIN:Bang('!UpdateMeasure', 'MeasureSummary')
    lastFetch = os.time()
  end

  render()
end

function OnData()
  local measure = SKIN:GetMeasure('MeasureSummaryJson')
  -- A rejected key arrives as a bare newline rather than an empty string.
  local body = (measure and measure:GetStringValue() or ''):match('^%s*(.-)%s*$')

  if body == '' then
    return OnError('empty')
  end

  -- WebParser cannot expose HTTP status codes, so error payloads such as a
  -- 429 body arrive as a normal response.
  local apiCode = body:match('"code"%s*:%s*"([^"]+)"')
  if apiCode then
    return OnError(apiCode)
  end

  local value = jsonNumber(body, 'totalValue')
  if not value then
    return OnError('unreadable response')
  end

  local override = var('CurrencySymbol', '')
  if override ~= '' then
    currencySymbol = override
  else
    local currency = (body:match('"currency"%s*:%s*"([A-Za-z]+)"') or ''):upper()
    currencySymbol = CURRENCY_SYMBOLS[currency] or (currency ~= '' and currency .. ' ' or '')
  end

  statusDetail = ''

  status = 'ok'
  lastValue = value
  updateBaseline(value)
  render()
end

function OnError(kind)
  status = 'error'
  kind = tostring(kind)
  if kind == 'connect' then
    statusDetail = 'Offline - showing last value'
  elseif kind == 'empty' then
    -- A rejected key/secret returns 401 with an empty body.
    statusDetail = 'Key or secret rejected?'
  elseif kind == 'TooManyRequests' or kind == 'BusinessException' then
    statusDetail = 'Rate limited'
  elseif kind:find('ApiKey') or kind:find('Authenticat') or kind:find('Scope') then
    statusDetail = 'API key rejected (' .. kind .. ')'
  else
    statusDetail = 'Error: ' .. kind
  end
  -- Never touches the baseline, so a bad response cannot poison the day change.
  render()
end

-- Rainmeter reads Settings.inc only when the skin loads, so a key pasted in
-- afterwards needs a full skin refresh to take effect.
local function settingsHaveCredentials()
  local file = io.open(paths.settings, 'r')
  if not file then return false end
  local content = '\n' .. file:read('*a')
  file:close()
  return content:find('\nApiKey%s*=%s*%S') ~= nil
    and content:find('\nApiSecret%s*=%s*%S') ~= nil
end

function Refresh()
  if status == 'nokey' then
    SKIN:Bang('!Refresh')
    return
  end
  local now = os.time()
  if now - lastFetch < minInterval then return end
  lastFetch = now
  SKIN:Bang('!CommandMeasure', 'MeasureSummary', 'Update')
end

-- Runs every few seconds (MeasureScript UpdateDivider). While no key is set,
-- watch Settings.inc and reload as soon as the key and secret are saved.
function Update()
  if status == 'nokey' and settingsHaveCredentials() then
    SKIN:Bang('!Refresh')
  end
  return lastValue or 0
end
