-- Skip when explicitly disabled (CodeMaster personal.sh sets WAKATIME_DISABLE=1).
if vim.env.WAKATIME_DISABLE == "1" then
  return {}
end

return {
  "wakatime/vim-wakatime",
}
