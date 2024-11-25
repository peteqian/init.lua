local M = {}

local function process_variables(config, variables)
  local function replace_var(value)
    if type(value) ~= "string" then
      return value
    end
    return value:gsub("%${(.-)}", function(var)
      if variables[var] then
        return variables[var]
      elseif var:match("^workspaceFolder}") then
        return vim.fn.getcwd()
      elseif var:match("^workspaceRoot}") then
        return vim.fn.getcwd()
      elseif var:match("^file}") then
        return vim.fn.expand("%:p")
      elseif var:match("^relativeFile}") then
        return vim.fn.expand("%:.")
      elseif var:match("^fileBasename}") then
        return vim.fn.expand("%:t")
      elseif var:match("^fileBasenameNoExtension}") then
        return vim.fn.expand("%:t:r")
      elseif var:match("^fileDirname}") then
        return vim.fn.expand("%:p:h")
      elseif var:match("^fileExtname}") then
        return vim.fn.expand("%:e")
      elseif var:match("^cwd}") then
        return vim.fn.getcwd()
      elseif var:match("^env:(.+)}") then
        local env_var = var:match("^env:(.+)}")
        return vim.fn.getenv(env_var) or ""
      end
      return value
    end)
  end

  local function process_table(tbl)
    local result = {}
    for k, v in pairs(tbl) do
      if type(v) == "table" then
        result[k] = process_table(v)
      else
        result[k] = replace_var(v)
      end
    end
    return result
  end

  return process_table(config)
end

local function strip_json_comments(str)
  local result = ""
  local in_string = false
  local in_single_comment = false
  local in_multi_comment = false
  local escape_next = false
  local i = 1

  while i <= #str do
    local c = str:sub(i, i)
    local next_c = str:sub(i + 1, i + 1)

    if escape_next then
      result = result .. c
      escape_next = false
    elseif in_string then
      if c == "\\" then
        escape_next = true
      elseif c == '"' then
        in_string = false
      end
      result = result .. c
    elseif in_single_comment then
      if c == "\n" then
        in_single_comment = false
        result = result .. c
      end
    elseif in_multi_comment then
      if c == "*" and next_c == "/" then
        in_multi_comment = false
        i = i + 1
      end
    else
      if c == '"' then
        in_string = true
        result = result .. c
      elseif c == "/" and next_c == "/" then
        in_single_comment = true
        i = i + 1
      elseif c == "/" and next_c == "*" then
        in_multi_comment = true
        i = i + 1
      elseif c == "," and str:sub(i + 1):match("^%s*[%]}]") then
        -- Skip trailing commas
      else
        result = result .. c
      end
    end
    i = i + 1
  end
  return result
end

function M.setup()
  local telescope = require("telescope")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  function M.get_launch_config()
    local launch_file = vim.fn.getcwd() .. "/.vscode/launch.json"
    if vim.fn.filereadable(launch_file) == 0 then
      vim.notify("No launch.json found in .vscode directory", vim.log.levels.ERROR)
      return nil
    end

    local content = vim.fn.readfile(launch_file)
    local json_str = strip_json_comments(table.concat(content, "\n"))
    local ok, decoded = pcall(vim.json.decode, json_str)
    if not ok then
      vim.notify("Failed to parse launch.json: " .. decoded, vim.log.levels.ERROR)
      return nil
    end
    return decoded
  end

  function M.launch_config(config)
    local cwd = vim.fn.getcwd()
    local variables = {
      workspaceFolder = cwd,
      workspaceRoot = cwd,
      file = vim.fn.expand("%:p"),
      relativeFile = vim.fn.expand("%:."),
      fileBasename = vim.fn.expand("%:t"),
      fileBasenameNoExtension = vim.fn.expand("%:t:r"),
      fileDirname = vim.fn.expand("%:p:h"),
      fileExtname = vim.fn.expand("%:e"),
      cwd = cwd,
    }

    local processed_config = process_variables(config, variables)

    -- Ensure program path is absolute
    if processed_config.program and not vim.fn.fnamemodify(processed_config.program, ":p") then
      processed_config.program = vim.fn.fnamemodify(processed_config.program, ":p")
    end

    -- Add common Node.js debug settings if missing
    if processed_config.type == "node" then
      processed_config.sourceMaps = true
      processed_config.resolveSourceMapLocations = { "${workspaceFolder}/**", "!**/node_modules/**" }
      processed_config.outFiles = { cwd .. "/dist/**/*.js", cwd .. "/build/**/*.js" }
    end

    local dap = require("dap")
    dap.run(processed_config)
  end

  function M.show_launch_configs()
    local launch_configs = M.get_launch_config()
    if not launch_configs then
      return
    end

    local configs = launch_configs.configurations
    local items = {}
    for _, config in ipairs(configs) do
      table.insert(items, {
        name = config.name,
        config = config,
      })
    end

    local picker = pickers.new({}, {
      prompt_title = "Launch Configurations",
      finder = finders.new_table({
        results = items,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.name,
            ordinal = entry.name,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            M.launch_config(selection.value.config)
          end
        end)
        return true
      end,
    })
    picker:find()
  end

  vim.api.nvim_create_user_command("LaunchConfig", M.show_launch_configs, {})
  vim.keymap.set("n", "<leader>dl", M.show_launch_configs, { desc = "Show Launch Configs" })
end

return M
