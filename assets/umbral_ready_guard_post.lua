-- Umbral: wait for the existing local party before leaving the observed HQ menu.
-- No Exec, connection, authentication or party-state writes. Remove and restart
-- to undo. Hash identities come from selector-diagnostic-05-*.txt, not guesses.
do
  local marker = "UMBRAL_READY_GUARD_V2"
  if rawget(_G, marker) then return end
  local clua = rawget(_G, "CLUA")
  local navigator = rawget(_G, "MenuNavigator")
  local lui = rawget(_G, "LUI")
  local flow = type(lui) == "table" and lui.FlowManager or nil
  local unpack_values = unpack or table.unpack
  if type(clua) ~= "table" or type(clua.PushXHash) ~= "function"
      or type(navigator) ~= "table" or type(navigator.QueueURIXHash) ~= "function"
      or type(flow) ~= "table" or type(flow.RequestAddMenu) ~= "function"
      or type(unpack_values) ~= "function" then return end
  local function pack(...) return { n = select("#", ...), ... } end
  local function log(text)
    local fn = rawget(_G, "DebugPrint")
    if type(fn) == "function" then pcall(fn, "k1 " .. marker .. " " .. text) end
  end
  local function H(value) return clua.PushXHash(value) end
  local hq = H("0xe51957c821558aef")
  local route = {
    H("0xbe991042123f73f7"), H("0x39cc1eaa62a04dc6"),
    H("0xd0193ff2a7549dd9"), H("0x89e9918304f5ed42")
  }
  local active_key = H("0xf63537242f1d48ff")
  local host_key = H("0x96957722ef74f5d2")
  local frontend_key = H("0x112586a3f4fb490e")
  local state = { armed = false, showing = false, attempts = 0 }
  local function field(owner, key)
    if owner == nil then return nil end
    local ok, value = pcall(function() return owner[key] end)
    if ok and value ~= nil then return value end
    local hash_ok, hash = pcall(H, key)
    if hash_ok then
      local get_ok, hashed = pcall(function() return owner[hash] end)
      if get_ok then return hashed end
    end
    return nil
  end
  local function player_count(controller)
    local source = field(field(field(rawget(_G, "DataSources"), "alwaysLoaded"), "privateParty"), "count")
    local get = field(source, "GetValue")
    if type(get) ~= "function" or type(controller) ~= "number" then return nil end
    local ok, value = pcall(get, source, controller)
    if ok and type(value) == "number" then return value end
    return nil
  end
  local function query(owner, key, text_key)
    if type(owner) ~= "table" then return nil, "missing-table" end
    local fn = text_key and owner[text_key] or nil
    if type(fn) ~= "function" then fn = owner[key] end
    if type(fn) ~= "function" then return nil, "missing-function" end
    local result = pack(pcall(fn))
    if not result[1] then return nil, "query-error" end
    if result.n ~= 2 or type(result[2]) ~= "boolean" then return nil, "non-boolean-result" end
    return result[2], "ok"
  end
  local function matches(uri)
    if type(uri) ~= "table" or rawget(uri, 5) ~= nil then return false end
    for i = 1, 4 do if rawget(uri, i) ~= route[i] then return false end end
    return true
  end
  local original_add = flow.RequestAddMenu
  flow.RequestAddMenu = function(name, ...)
    local result = pack(original_add(name, ...))
    if name == hq then
      state.armed = true
      log("HQ observed; guard armed")
    end
    return unpack_values(result, 1, result.n)
  end
  local original_queue = navigator.QueueURIXHash
  navigator.QueueURIXHash = function(uri, controller, ...)
    if state.armed and not state.showing and matches(uri) then
      local frontend = query(rawget(_G, "Engine"), frontend_key, "InFrontend")
      -- Do not intercept gameplay, return navigation or unidentified contexts.
      if frontend == true then
        local lobby = rawget(_G, "Lobby")
        local active, active_reason = query(lobby, active_key)
        local host, host_reason = query(lobby, host_key)
        local count = player_count(controller)
        state.attempts = state.attempts + 1
        if state.attempts <= 20 then
          log("attempt=" .. state.attempts .. " active=" .. tostring(active)
            .. " host=" .. tostring(host) .. " activeReason=" .. active_reason
            .. " hostReason=" .. host_reason .. " count=" .. tostring(count))
        end
        if active ~= true or host ~= true or count ~= 1 then
          local popup = flow.RequestErrorPopup
          if type(popup) == "function" and type(controller) == "number" then
            state.showing = true
            local ok = pcall(popup, controller, "Preparando Zombies",
              "La sesion local aun no esta lista. Espera unos segundos en este menu y vuelve a pulsar Jugar.")
            state.showing = false
            if not ok then log("readiness popup failed") end
          else
            log("readiness popup unavailable")
          end
          return
        end
        state.armed = false
        log("local party ready; original navigation permitted")
      end
    end
    return original_queue(uri, controller, ...)
  end
  rawset(_G, marker, state)
  log("installed; awaiting observed HQ menu")
end
