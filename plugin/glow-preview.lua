vim.api.nvim_create_user_command("GlowPreview", function()
  require("glow-preview").open()
end, {})
