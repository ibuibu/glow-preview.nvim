local M = {}

local state = {
  preview_buf = nil,
  preview_win = nil,
  md_buf = nil,
  augroup = nil,
  timer = nil,
  tmpfile = nil,
}

local DEBOUNCE_MS = 300

function M.render()
  if not state.preview_win or not vim.api.nvim_win_is_valid(state.preview_win) then
    return
  end
  if not state.md_buf or not vim.api.nvim_buf_is_valid(state.md_buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(state.md_buf, 0, -1, false)
  local content = table.concat(lines, "\n")

  if not state.tmpfile then
    state.tmpfile = vim.fn.tempname() .. ".md"
  end
  local f = io.open(state.tmpfile, "w")
  if not f then
    return
  end
  f:write(content)
  f:close()

  local width = vim.api.nvim_win_get_width(state.preview_win)
  local cmd = string.format("glow -w %d %s", width, vim.fn.shellescape(state.tmpfile))

  -- Create a fresh terminal buffer (old one auto-wiped via bufhidden)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_win_set_buf(state.preview_win, buf)
  state.preview_buf = buf

  -- Run glow in a real PTY so ANSI colors work
  local cur_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(state.preview_win)
  vim.fn.termopen(cmd)
  vim.api.nvim_set_current_win(cur_win)
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
  state.preview_win = vim.api.nvim_get_current_win()

  -- Window options
  vim.wo[state.preview_win].number = false
  vim.wo[state.preview_win].relativenumber = false
  vim.wo[state.preview_win].signcolumn = "no"
  vim.wo[state.preview_win].wrap = true

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
  if state.tmpfile then
    os.remove(state.tmpfile)
    state.tmpfile = nil
  end
  state.preview_buf = nil
  state.preview_win = nil
  state.md_buf = nil
end

return M
