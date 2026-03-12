local M = {}

local state = {
  preview_buf = nil,
  preview_win = nil,
  md_buf = nil,
  chan = nil,
  augroup = nil,
  timer = nil,
}

local DEBOUNCE_MS = 300

function M.render()
  if not state.chan then
    return
  end
  if not state.preview_win or not vim.api.nvim_win_is_valid(state.preview_win) then
    return
  end
  if not state.md_buf or not vim.api.nvim_buf_is_valid(state.md_buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(state.md_buf, 0, -1, false)
  local content = table.concat(lines, "\n")

  local tmpfile = vim.fn.tempname() .. ".md"
  local f = io.open(tmpfile, "w")
  if not f then
    return
  end
  f:write(content)
  f:close()

  local width = vim.api.nvim_win_get_width(state.preview_win)

  vim.fn.jobstart({ "glow", "-w", tostring(width), tmpfile }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not state.chan then
        return
      end
      local output = table.concat(data, "\n")
      vim.schedule(function()
        if state.chan then
          vim.api.nvim_chan_send(state.chan, "\x1b[2J\x1b[H")
          vim.api.nvim_chan_send(state.chan, output)
        end
      end)
    end,
    on_exit = function()
      os.remove(tmpfile)
    end,
  })
end

local function schedule_render()
  if state.timer then
    state.timer:stop()
  end
  state.timer = vim.defer_fn(function()
    M.render()
  end, DEBOUNCE_MS)
end

function M.open()
  -- Toggle: already open -> close
  if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
    M.close()
    return
  end

  if vim.fn.executable("glow") ~= 1 then
    vim.notify("glow is not installed", vim.log.levels.ERROR)
    return
  end

  if vim.bo.filetype ~= "markdown" then
    vim.notify("Not a markdown file", vim.log.levels.WARN)
    return
  end

  state.md_buf = vim.api.nvim_get_current_buf()
  local md_win = vim.api.nvim_get_current_win()

  -- Open right split
  vim.cmd("botright vsplit")
  state.preview_buf = vim.api.nvim_create_buf(false, true)
  state.preview_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.preview_win, state.preview_buf)

  -- Preview buffer/window options
  vim.bo[state.preview_buf].bufhidden = "wipe"
  vim.wo[state.preview_win].number = false
  vim.wo[state.preview_win].relativenumber = false
  vim.wo[state.preview_win].signcolumn = "no"
  vim.wo[state.preview_win].wrap = true

  -- Virtual terminal for ANSI color rendering
  state.chan = vim.api.nvim_open_term(state.preview_buf, {})

  -- Autocommands
  state.augroup = vim.api.nvim_create_augroup("GlowPreview", { clear = true })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = state.md_buf,
    group = state.augroup,
    callback = schedule_render,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = state.augroup,
    callback = function(args)
      if tonumber(args.match) == state.preview_win then
        M.close()
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = state.md_buf,
    group = state.augroup,
    callback = function()
      M.close()
    end,
  })

  -- Focus back to markdown buffer
  vim.api.nvim_set_current_win(md_win)

  -- Initial render
  M.render()
end

function M.close()
  if state.timer then
    state.timer:stop()
    state.timer = nil
  end
  if state.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
    state.augroup = nil
  end
  if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
    vim.api.nvim_win_close(state.preview_win, true)
  end
  state.preview_buf = nil
  state.preview_win = nil
  state.chan = nil
  state.md_buf = nil
end

return M
