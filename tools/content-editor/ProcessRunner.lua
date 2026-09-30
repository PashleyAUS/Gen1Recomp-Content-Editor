local ProcessRunner = {}
local windowsFfi
local windowsFfiInitialized = false

local function isWindows()
  local osName = love and love.system and love.system.getOS and love.system.getOS()
  if osName then return osName == "Windows" end
  return package.config:sub(1, 1) == "\\"
end

local function readFile(path)
  local file = io.open(path, "rb")
  if not file then return "" end
  local contents = file:read("*a") or ""
  file:close()
  return contents
end

local function portableRun(command)
  local ok, handle = pcall(io.popen, command .. " 2>&1")
  if not ok or not handle then
    return false, "shell unavailable: " .. tostring(handle)
  end
  local output = handle:read("*a") or ""
  local okClose, _, code = handle:close()
  local exitCode = type(code) == "number" and code or (okClose and 0 or 1)
  return exitCode == 0, output, exitCode
end

local function getWindowsFfi()
  if windowsFfiInitialized then return windowsFfi end
  windowsFfiInitialized = true
  local okFfi, ffi = pcall(require, "ffi")
  if not okFfi then return nil end
  -- Own names, bound with asm(). Another module (the updater) also declares
  -- CreateProcessA, and LuaJIT keeps whichever declaration came first, so a
  -- later call with the other struct crashes instead of starting the process.
  local okCdef = pcall(ffi.cdef, [[
    typedef struct {
      unsigned long cb; char *lpReserved; char *lpDesktop; char *lpTitle;
      unsigned long dwX; unsigned long dwY; unsigned long dwXSize; unsigned long dwYSize;
      unsigned long dwXCountChars; unsigned long dwYCountChars; unsigned long dwFillAttribute;
      unsigned long dwFlags; unsigned short wShowWindow; unsigned short cbReserved2;
      unsigned char *lpReserved2; void *hStdInput; void *hStdOutput; void *hStdError;
    } CE_STARTUPINFOA;
    typedef struct { void *hProcess; void *hThread; unsigned long dwProcessId; unsigned long dwThreadId; }
      CE_PROCESS_INFORMATION;
    int CE_CreateProcessA(const char *, char *, void *, void *, int, unsigned long, void *,
      const char *, CE_STARTUPINFOA *, CE_PROCESS_INFORMATION *) asm("CreateProcessA");
    unsigned long CE_WaitForSingleObject(void *, unsigned long) asm("WaitForSingleObject");
    int CE_GetExitCodeProcess(void *, unsigned long *) asm("GetExitCodeProcess");
    int CE_CloseHandle(void *) asm("CloseHandle");
  ]])
  if not okCdef then return nil end
  windowsFfi = ffi
  return windowsFfi
end

local function tempBase()
  local tmp = os.getenv("TEMP") or os.getenv("TMP") or os.getenv("TMPDIR")
  local name = "pokeport_ce_" .. tostring(os.time()) .. "_"
    .. tostring(math.random(100000, 999999))
  if tmp and tmp ~= "" then
    return tmp .. package.config:sub(1, 1) .. name
  end
  -- LuaJIT on Windows often returns a drive-root name (\sXXXX) that is not writable.
  local fallback = os.tmpname()
  os.remove(fallback)
  return fallback
end

local function windowsRun(command)
  local ffi = getWindowsFfi()
  if not ffi then return portableRun(command) end

  local base = tempBase()
  local batchPath = base .. ".bat"
  local outputPath = base .. ".out"
  local batch = io.open(batchPath, "wb")
  if not batch then return false, "could not create validation command file" end
  batch:write("@echo off\r\n", command, "\r\nexit /b %errorlevel%\r\n")
  batch:close()

  local commandLine = string.format(
    'cmd.exe /d /s /c "call ""%s"" > ""%s"" 2>&1"', batchPath, outputPath)
  local buffer = ffi.new("char[?]", #commandLine + 1, commandLine)
  local startup = ffi.new("CE_STARTUPINFOA")
  startup.cb = ffi.sizeof(startup)
  local process = ffi.new("CE_PROCESS_INFORMATION")
  local created = ffi.C.CE_CreateProcessA(nil, buffer, nil, nil, 0, 0x08000000,
    nil, nil, startup, process)
  if created == 0 then
    os.remove(batchPath)
    return false, "could not start hidden Windows command"
  end

  ffi.C.CE_CloseHandle(process.hThread)
  ffi.C.CE_WaitForSingleObject(process.hProcess, 0xFFFFFFFF)
  local exitCode = ffi.new("unsigned long[1]")
  ffi.C.CE_GetExitCodeProcess(process.hProcess, exitCode)
  ffi.C.CE_CloseHandle(process.hProcess)

  local output = readFile(outputPath)
  os.remove(batchPath)
  os.remove(outputPath)
  local code = tonumber(exitCode[0])
  return code == 0, output, code
end

function ProcessRunner.run(command)
  if isWindows() then return windowsRun(command) end
  return portableRun(command)
end

return ProcessRunner
