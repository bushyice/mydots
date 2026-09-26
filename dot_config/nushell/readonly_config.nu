$env.config.color_config = {
  separator: "#45475a"
  leading_trailing_space_bg: "#585b70"
  header: "#a6e3a1"
  date: "#cba6f7"
  filesize: "#89b4fa"
  row_index: "#94e2d5"
  bool: "#f38ba8"
  int: "#a6e3a1"
  duration: "#f38ba8"
  range: "#f38ba8"
  float: "#f38ba8"
  string: "#585b70"
  nothing: "#f38ba8"
  binary: "#f38ba8"
  cellpath: "#f38ba8"
  hints: dark_gray

  shape_garbage: { fg: "#b4befe" bg: "#f38ba8" }
  shape_bool: "#89b4fa"
  shape_int: { fg: "#cba6f7" attr: b }
  shape_float: { fg: "#cba6f7" attr: b }
  shape_range: { fg: "#f9e2af" attr: b }
  shape_internalcall: { fg: "#94e2d5" attr: b }
  shape_external: "#94e2d5"
  shape_externalarg: { fg: "#a6e3a1" attr: b }
  shape_literal: "#89b4fa"
  shape_operator: "#f9e2af"
  shape_signature: { fg: "#a6e3a1" attr: b }
  shape_string: "#a6e3a1"
  shape_filepath: "#89b4fa"
  shape_globpattern: { fg: "#89b4fa" attr: b }
  shape_variable: "#cba6f7"
  shape_flag: { fg: "#89b4fa" attr: b }
  shape_custom: { attr: b }
}



      let carapace_completer = {|spans|
        carapace $spans.0 nushell ...$spans | from json
      }
      
      $env.config = {
       show_banner: false,
       completions: {
         case_sensitive: false
         quick: true
         partial: true
         algorithm: "fuzzy"
         external: {
	       enable: true 
	       max_results: 100 
	       completer: $carapace_completer # check 'carapace_completer' 
	     }
       },
       # history: {
       #     sync_on_enter: true     # Set to false so history isn't shared/synced across active sessions instantly (persists only on exit)
       #    isolation: true
       #    file_format: "sqlite"
       # },
       keybindings: [
         {
           name: backward_kill_word
           modifier: control
           keycode: char_h
           mode: [emacs, vi_insert]
           event: [
             { edit: BackspaceWord }
           ]
         }
       ]
      }

      alias hx = helix;
      
      $env.PATH = ($env.PATH | 
        split row (char esep) |
        prepend /home/makano/exploit/bin |
        prepend /home/makano/.nix-profile/bin |
        prepend /home/makano/.nix-profile.bak/bin |
        prepend /home/makano/.local/bin |
        prepend /home/makano/.cargo/bin
      )

      # $env.config.hooks.env_change.PWD = ($env.config.hooks.env_change.PWD? | default [])
      # $env.config.hooks.env_change.PWD ++= [{||
      #   if (which direnv | is-empty) {
      #     return
      #   }
      #   direnv export json | from json | default {} | load-env
      #   # If direnv changes the PATH, convert it to a list
      #   if ($env.PATH | describe | str contains "string") {
      #     $env.PATH = ($env.PATH | split row (char esep))
      #   }
      # }] 

source zoxide.nu

use starship.nu

source carapace.nu

$env.config = ($env.config? | default {})
$env.config.hooks = ($env.config.hooks? | default {})
$env.config.hooks.pre_prompt = (
    $env.config.hooks.pre_prompt?
    | default []
    | append {||
        direnv export json
        | from json --strict
        | default {}
        | items {|key, value|
            let value = do (
                {
                  "PATH": {
                    from_string: {|s| $s | split row (char esep) | path expand --no-symlink }
                    to_string: {|v| $v | path expand --no-symlink | str join (char esep) }
                  }
                }
                | merge ($env.ENV_CONVERSIONS? | default {})
                | get ([[value, optional, insensitive]; [$key, true, true] [from_string, true, false]] | into cell-path)
                | if ($in | is-empty) { {|x| $x} } else { $in }
            ) $value
            return [ $key $value ]
        }
        | into record
        | load-env
    }
)

$env.config.history.file_format = "sqlite"
$env.config.history.isolation = true

# $env.config.hinter.closure = {|ctx|
#     if ($ctx.line | is-empty) {
#         return null
#     }

#     let candidate = (
#         history
#         | get command
#         | where {|cmd| $cmd | str starts-with $ctx.line }
#         | last
#     )

#     if ($candidate == null) {
#         null
#     } else {
#         $candidate | str substring ($ctx.line | str length)..
#     }
# }

$env.config.hinter.closure = {|ctx|
    if ($ctx.line | is-empty) { return null }

    let escaped_line = ($ctx.line | str replace --all "'" "''")
    let sql = $"SELECT command_line FROM history WHERE command_line LIKE '($escaped_line)%' ORDER BY id DESC LIMIT 1;"

    let result = (sqlite3 $nu.history-path $sql | str trim)

    if ($result | is-empty) {
        null
    } else {
        $result | str substring ($ctx.line | str length)..
    }
}
