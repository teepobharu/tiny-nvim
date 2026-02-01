#!/usr/bin/env bash

LOGFILE="$HOME/dotfiles/.config/nvim3_jelly_tinynvim/tests/debug_me.log"
exec 3>&1 4>&2                   # Save original stdout and stderr
exec > >(tee -a "$LOGFILE") 2>&1 # Redirect stdout and stderr to both terminal and log file

echo "========================="
date +"%Y-%m-%d %H:%M:%S Starting debug_me.sh"
echo "========================="

interactive_read() {
  exec 1>&3 2>&4 # Restore stdout/stderr to terminal for the prompt
  echo " ============================= "
  read "$@"
  exec > >(tee -a "$LOGFILE") 2>&1 # Re-redirect stdout/stderr to both terminal and log file
  echo " ============================= "
}

# all vars from .bash.local,  ~/.bash_exports
vars=(
  FOO
  BAR
  SHLVL
  SHELL
  OGSHELL
  JAVA_HOME
  NVIM_APPNAME
  CLAUDE_CODE_USE_BEDROCK
  CLAUDE_CODE_SKIP_BEDROCK_AUTH
  K9S_FEATURE_GATE_NODE_SHELL
)
vars_mask=(
  MMB_FORKWEBHOOK
  TRIPVIEW_BFF_SLACK_WEBHOOK_URL
  TRIPVIEW_BFF_SLACK_WEBHOOK_URL
  OPENAI_BASE_URL
  GITLAB_TOKEN
  GITLAB_PERSONAL_ACCESS_TOKEN
  AG_SRC_ACCESS_TOKEN
  FECART_NPMTOKEN
  NPMTOKEN
  GLEANTOKEN
  GENAIAG
  GGEMAI
  GGEMAIFREE
  GGEMINI
  SUPAB_SHOPCART
  GEMINI_API_KEY
  GOOGLE_GENERATIVE_AI_API_KEY
  ANTHROPIC_AUTH_TOKEN
  AVANTE_OPENAI_API_KEY
  OPENCODE_SERVER_PASSWORD
  AVANTE_ANTHROPIC_API_KEY
  OPENAI_API_KEY
  GOOGLE_SEARCH_API_KEY
  DEEPSEEKAPIKEY
  GRIST_THG_KEY
  PORTAL_TOKEN
  USER_DEVPORTAL_TOKEN_BB
  TAVILY_API_KEY
  GOOGLE_SEARCH_ENGINE_ID
  JIRA_API_TOKEN
  ANTHROPIC_BEDROCK_BASE_URL
  GH_COM
  AVANTE_OPENAI_API_KEY
  OPENCODE_SERVER_PASSWORD
  AVANTE_ANTHROPIC_API_KEY
)

printEnv() {
  for n in "${vars[@]}"; do
    if printenv "$n" >/dev/null; then
      v=$(printenv "$n") # exported env only
      printf '%s=%q\n' "$n" "$v"
    else
      printf '%s=<unset>\n' "$n"
    fi
  done
}

printEnvMasked() {
  for n in "${vars_mask[@]}"; do
    if printenv "$n" >/dev/null; then
      # Show only the first 2 and last 2 characters for masked vars
      masked_value="${!n}"
      value_len=${#masked_value}
      if [ "$value_len" -le 7 ]; then
        # For short values, mask everything except first and last char
        printf '%s=%s***hidden***%s\n' "$n" "${masked_value:0:1}" "${masked_value: -1}"
      else
        # For longer values, mask middle portion
        printf '%s=%s***hidden(%d)***%s\n' "$n" "${masked_value:0:3}" "$((value_len - 7))" "${masked_value: -4}"
      fi
    else
      printf '%s=<unset>\n' "$n"
    fi
  done
}

printEnv
printEnvMasked

interactive_read -p "======== Continue print env ================" _

# do env but avoid printing line that matched in vars_mask
# vars_mask=(
#   "MMB_FORKWEBHOOK"
#   "TRIPVIEW_BFF_SLACK_WEBHOOK_URL"
# )

vars_ignore_env=(
  "FZF_ALT_C_OPTS"
  "INSTRUCTIONS"
  "INSTRUCTIONS_GIT"
)
# combined vars_mask
vars_ignore_env=(
  "${vars_mask[@]}"
  "${vars_ignore_env[@]}"
)

# avoid printing vars in vars_ignore_env and only print lines with prefix 'NONSPACECHAR='
env | grep -v -E "$(
  IFS='|'
  echo "${vars_ignore_env[*]}"
)" | grep -E '^[^[:space:]]+='

# Print environment variables, masking values if the variable is in vars_mask
# vars_mask=(SECRET_KEY PASSWORD API_TOKEN)
# for var in $(env | cut -d= -f1); do
#   val=$(printenv "$var")
#   masked=false
#   for mask in "${vars_mask[@]}"; do
#     if [ "$var" = "$mask" ]; then
#       masked=true
#       break
#     fi
#   done
#   if [ "$masked" = true ]; then
#     echo "$var=***MASKED***"
#   else
#     echo "$var=$val"
#   fi
# done

export ASDASD=12345
interactive_read -p "Call another subshell to print above env" _
bash -c 'echo "
OPENAI_BASE_URL = $OPENAI_BASE_URL
ASDASD = $ASDASD
FOO = $FOO
BAR = $BAR
"'

interactive_read -p "_TMUX Show env" _
echo "-----TMUX_ global specific ----"
tmux show-environment -g | grep -v -E "$(
  IFS='|'
  echo "${vars_ignore_env[*]}"
)" | grep -E '^[^[:space:]]+='

echo "----TMUX_ session specific ----"
tmux show-environment -s
interactive_read -p "Ending" _

interactive_read -r -n 1 -s -p "Press any key to exit..."
# # CONFIG SCRIPT CHANGE START
#  MMB_FORKWEBHOOK=
#  TRIPVIEW_BFF_SLACK_WEBHOOK_URL=
#  TRIPVIEW_BFF_SLACK_WEBHOOK_URL=
#  JAVA_HOME=
#  NVIM_APPNAME=
#  GITLAB_TOKEN=
#  GITLAB_PERSONAL_ACCESS_TOKEN=
# #  SRC_ACCESS_TOKEN=
#  AG_SRC_ACCESS_TOKEN=
#  FECART_NPMTOKEN=
#  NPMTOKEN=
#  GLEANTOKEN=
#  GENAIAG=
#  GGEMAI=
#  GGEMAIFREE=
#  GGEMINI=
#  SUPAB_SHOPCART=
#  GEMINI_API_KEY=
#  GOOGLE_GENERATIVE_AI_API_KEY=
#  CLAUDE_CODE_USE_BEDROCK=
#  CLAUDE_CODE_SKIP_BEDROCK_AUTH=
#  ANTHROPIC_AUTH_TOKEN=
#  AVANTE_OPENAI_API_KEY=
#  OPENCODE_SERVER_PASSWORD=
#  AVANTE_ANTHROPIC_API_KEY=
#  OPENAI_API_KEY=
#  GOOGLE_SEARCH_API_KEY=
#  DEEPSEEKAPIKEY=
#  GRIST_THG_KEY=
#  PORTAL_TOKEN=
# # use https://dev-portal.agodadev.io/auth/userinfo
#  USER_DEVPORTAL_TOKEN_BB=
#
#  TAVILY_API_KEY=
#  GOOGLE_SEARCH_ENGINE_ID=
# # does not seem to have ping on some contrainer , no
#  K9S_FEATURE_GATE_NODE_SHELL=
#  JIRA_API_TOKEN=
#
# "CLAUDE_CODE_USE_BEDROCK": "1",
# "CLAUDE_CODE_SKIP_BEDROCK_AUTH": "1",
# "ANTHROPIC_BEDROCK_BASE_URL": "https://genai-gateway.agoda.is/claude",
#  ANTHROPIC_AUTH_TOKEN=
# CONFIG SCRIPT CHANGE END
