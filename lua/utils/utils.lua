-- /nvim/lua/utils/utils.lua
-- Optimized Plenary modules integration with lazy loading

local M = {}

-- Create a lazy loader for modules to improve startup time
local function lazy_require(module_name)
  local mt = {}

  mt.__index = function(_, key)
    local module = require(module_name)
    return module[key]
  end

  mt.__call = function(_, ...)
    local module = require(module_name)
    return module(...)
  end

  return setmetatable({}, mt)
end

-- Lazy load essential modules
local async = lazy_require('plenary.async')
local async_lib = lazy_require('plenary.async_lib')
local Job = lazy_require('plenary.job')
local Path = lazy_require('plenary.path')
local scan = lazy_require('plenary.scandir')
local context = lazy_require('plenary.context_manager')
local test = lazy_require('plenary.test_harness')
local filetype = lazy_require('plenary.filetype')
local strings = lazy_require('plenary.strings')

-- Simple LRU cache implementation for better memory management
local function create_lru_cache(max_size)
  max_size = max_size or 100
  local cache = {}
  local keys_queue = {}

  return {
    get = function(key)
      return cache[key]
    end,

    set = function(key, value)
      if #keys_queue >= max_size and not cache[key] then
        local oldest_key = table.remove(keys_queue, 1)
        cache[oldest_key] = nil
      end

      if not cache[key] then
        table.insert(keys_queue, key)
      end

      cache[key] = value
      return value
    end,

    clear = function()
      cache = {}
      keys_queue = {}
    end,

    size = function()
      return #keys_queue
    end
  }
end

-- Async utilities with error handling
M.async = {
  run = function(fn)
    local ok, result = pcall(async.run, fn)
    if not ok then
      vim.schedule(function()
        vim.notify("Async error: " .. tostring(result), vim.log.levels.ERROR)
      end)
      return nil
    end
    return result
  end,

  void = function(fn)
    return async.void(function()
      local ok, result = pcall(fn)
      if not ok then
        vim.schedule(function()
          vim.notify("Async error: " .. tostring(result), vim.log.levels.ERROR)
        end)
      end
      return result
    end)
  end,

  await = async.await,

  run_job = function(cmd, args, cwd, on_exit)
    return M.async.run(function()
      local job = Job:new({
        command = cmd,
        args = args,
        cwd = cwd or vim.fn.getcwd(),
        on_exit = on_exit
      })
      return job:sync()
    end)
  end
}

-- Optimized async_lib utilities
M.async_lib = {
  async_void = async_lib.async_void,
  await = async_lib.await,

  throttle = function(fn, ms)
    local timer = vim.loop.new_timer()
    local running = false
    local pending_args

    return function(...)
      pending_args = {...}

      if not running then
        running = true
        local args = pending_args
        pending_args = nil

        timer:start(ms, 0, vim.schedule_wrap(function()
          fn(unpack(args))
          running = false

          if pending_args then
            local next_args = pending_args
            pending_args = nil
            fn(unpack(next_args))
          end
        end))
      end
    end
  end,

  debounce = function(fn, ms)
    local timer = vim.loop.new_timer()

    return function(...)
      local args = {...}

      timer:stop()
      timer:start(ms, 0, vim.schedule_wrap(function()
        fn(unpack(args))
      end))
    end
  end
}

-- Job management with improved error handling
M.job = {
  start = Job.start,

  create = function(opts)
    opts = opts or {}

    -- Add default error handling
    local user_on_stderr = opts.on_stderr
    opts.on_stderr = function(_, data)
      if user_on_stderr then
        user_on_stderr(_, data)
      elseif data and data ~= "" then
        vim.schedule(function()
          vim.notify("Job error: " .. data, vim.log.levels.WARN)
        end)
      end
    end

    return Job:new({
      command = opts.command,
      args = opts.args,
      cwd = opts.cwd or vim.fn.getcwd(),
      on_stdout = opts.on_stdout,
      on_stderr = opts.on_stderr,
      on_exit = opts.on_exit,
      enable_recording = opts.enable_recording or false,
      env = opts.env,
      interactive = opts.interactive or false
    })
  end,

  exec = function(cmd, args, cwd)
    local results = {}
    local stderr_data = {}
    local success = true

    local job = Job:new({
      command = cmd,
      args = args,
      cwd = cwd or vim.fn.getcwd(),
      on_stdout = function(_, data)
        if data and data ~= "" then
          table.insert(results, data)
        end
      end,
      on_stderr = function(_, data)
        if data and data ~= "" then
          table.insert(stderr_data, data)
          success = false
        end
      end,
      enable_recording = false
    })

    job:sync()

    if not success and #stderr_data > 0 then
      vim.schedule(function()
        vim.notify("Job error: " .. table.concat(stderr_data, "\n"), vim.log.levels.WARN)
      end)
    end

    return results, success
  end
}

-- Path utilities with improved caching
M.path = setmetatable({
  new = Path.new,

  -- Use LRU cache for paths
  _cache = create_lru_cache(100),

  get = function(self, path_str)
    if not path_str then return nil end

    local cached = self._cache:get(path_str)
    if not cached then
      cached = self._cache:set(path_str, Path:new(path_str))
    end
    return cached
  end,

  exists = function(path_str)
    if not path_str then return false end
    return vim.fn.filereadable(path_str) == 1 or vim.fn.isdirectory(path_str) == 1
  end,

  -- More robust path joining
  join = function(...)
    local args = {...}
    local result = ""
    local sep = Path.path.sep

    for i, segment in ipairs(args) do
      if i == 1 then
        result = segment
      else
        -- Handle cases where segments have trailing/leading separators
        if result:sub(-1) == sep then
          if segment:sub(1, 1) == sep then
            result = result .. segment:sub(2)
          else
            result = result .. segment
          end
        else
          if segment:sub(1, 1) == sep then
            result = result .. segment
          else
            result = result .. sep .. segment
          end
        end
      end
    end

    return result
  end
}, {
  __index = function(_, key)
    return Path[key]
  end
})

-- Directory scanning with TTL-based caching
M.scandir = {
  scan_dir = scan.scan_dir,

  scan_cached = (function()
    local cache = create_lru_cache(50)
    local last_update = {}
    local DEFAULT_TTL = 5000 -- milliseconds

    return function(path, opts)
      opts = opts or {}
      local ttl = opts.ttl or DEFAULT_TTL
      local cache_key = path .. vim.inspect(opts)
      local now = vim.loop.now()

      -- Check if cache entry exists and is fresh
      local cached_result = cache:get(cache_key)
      local last_updated = last_update[cache_key] or 0

      if cached_result and (now - last_updated < ttl) then
        return vim.deepcopy(cached_result) -- Return a copy to prevent mutation
      end

      -- Perform scan and update cache
      local results = scan.scan_dir(path, opts)
      cache:set(cache_key, results)
      last_update[cache_key] = now

      return vim.deepcopy(results)
    end
  end)(),

  find = function(path, pattern, opts)
    opts = opts or {}
    local results = {}

    -- Check if path exists to avoid errors
    if not M.path.exists(path) then
      vim.notify("Path does not exist: " .. path, vim.log.levels.WARN)
      return results
    end

    local paths = scan.scan_dir(path, opts)

    -- Use pcall for pattern matching to avoid errors with invalid patterns
    for _, file_path in ipairs(paths) do
      local ok, match = pcall(function() return file_path:match(pattern) end)
      if ok and match then
        table.insert(results, file_path)
      end
    end

    return results
  end
}

-- Context manager with improved error handling
M.context_manager = {
  with = context.with,

  open = function(filepath, mode, callback)
    -- Ensure the file exists before attempting to open
    if mode:match('r') and not M.path.exists(filepath) then
      error("File does not exist: " .. filepath)
    end

    -- Create directory if needed for write operations
    if mode:match('w') or mode:match('a') then
      local dir = vim.fn.fnamemodify(filepath, ":h")
      if not M.path.exists(dir) then
        vim.fn.mkdir(dir, "p")
      end
    end

    return context.with(io.open, filepath, mode, callback)
  end,

  with_setting = function(setting, value, callback)
    if not vim.o[setting] then
      vim.notify("Warning: setting '" .. setting .. "' does not exist", vim.log.levels.WARN)
    end

    local old_value = vim.o[setting]
    vim.o[setting] = value

    local ok, result = pcall(callback)
    vim.o[setting] = old_value

    if not ok then
      error(result)
    end

    return result
  end
}

-- Test harness improvements
M.test_harness = {
  describe = test.describe,

  run_test = function(name, fn)
    test.describe(name, function()
      test.it("runs", function()
        local ok, err = pcall(fn)
        assert(ok, err)
      end)
    end)
  end,

  benchmark = function(name, fn, iterations, warmup)
    iterations = iterations or 100
    warmup = warmup or math.floor(iterations * 0.1)

    test.describe("Benchmark: " .. name, function()
      test.it("performance", function()
        -- Warm up to avoid measuring JIT compilation time
        for _ = 1, warmup do
          fn()
        end

        local start = vim.loop.hrtime()
        for _ = 1, iterations do
          fn()
        end
        local end_time = vim.loop.hrtime()
        local duration = (end_time - start) / 1000000000 -- Convert to seconds
        print(string.format("%s: %.6f seconds (avg: %.9f)", name, duration, duration/iterations))
      end)
    end)
  end
}

-- Filetype detection with improved caching
M.filetype = {
  detect_from_name = filetype.detect_from_name,

  -- Use LRU cache for filetype detection
  _cache = create_lru_cache(200),

  detect = function(path)
    if not path then return nil end

    local cached = M.filetype._cache:get(path)
    if cached then
      return cached
    end

    local ft = filetype.detect_from_name(path)
    M.filetype._cache:set(path, ft)
    return ft
  end,

  clear_cache = function()
    M.filetype._cache:clear()
  end
}

-- String utilities with improved implementations
M.strings = {
  dedent = strings.dedent,

  -- More robust trim implementation
  trim = function(s)
    if not s then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
  end,

  -- Improved split with proper edge case handling
  split = function(s, sep, plain)
    if not s then return {} end
    if s == "" then return {} end

    sep = sep or "%s+"
    local result = {}
    local i = 1

    if plain then
      -- Plain pattern splitting (faster for simple separators)
      local start = 1
      repeat
        local b, e = s:find(sep, start, true)
        if b then
          table.insert(result, s:sub(start, b - 1))
          start = e + 1
        else
          table.insert(result, s:sub(start))
        end
      until not b
    else
      -- Regex pattern splitting
      for match in (s..sep):gmatch("(.-)"..sep) do
        result[i] = match
        i = i + 1
      end
    end

    return result
  end,

  -- Check if string starts with prefix
  starts_with = function(str, prefix)
    return str:sub(1, #prefix) == prefix
  end,

  -- Check if string ends with suffix
  ends_with = function(str, suffix)
    return suffix == "" or str:sub(-#suffix) == suffix
  end
}

-- Add utility for executing commands and capturing output
M.cmd = {
  -- Execute vim command and return output
  capture = function(command)
    local output = vim.fn.execute(command)
    return M.strings.trim(output)
  end,

  -- Run system command and return output
  system = function(command)
    local output = vim.fn.system(command)
    return M.strings.trim(output)
  end
}

-- Clear all caches
M.clear_caches = function()
  M.path._cache:clear()
  M.filetype._cache:clear()
  collectgarbage("collect")
end

-- Lazy initialize only when first used
local initialized = false
setmetatable(M, {
  __index = function(t, k)
    if not initialized and t[k] then
      initialized = true
      -- Initialize on first use
      local common_paths = {
        vim.fn.stdpath("config"),
        vim.fn.stdpath("data"),
        vim.fn.getcwd()
      }

      for _, path in ipairs(common_paths) do
        M.path:get(path)
      end
    end
    return rawget(t, k)
  end
})

return M
