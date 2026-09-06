local function open_instruction_picker()
  local ok, lazy = pcall(require, "lazy")
  if ok then
    lazy.load { plugins = { "snacks.nvim" } }
  end
  require("utils.instruction_picker").open()
end

-- Registering the command while the spec is imported avoids replacing the
-- existing snacks.nvim `init` function when Lazy merges duplicate specs.
if vim.fn.exists ":InstructionFiles" == 0 then
  vim.api.nvim_create_user_command("InstructionFiles", open_instruction_picker, {
    desc = "Browse AI instruction, rule, and skill files",
  })
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>fI", open_instruction_picker, desc = "Instruction files" },
    },
  },
}
