# ~/.config/fish/conf.d/macos.fish

# Quick Look from terminal
abbr -a ql "qlmanage -p"

# Open current directory in Finder
abbr -a finder "open ."

# Flush DNS
abbr -a flushdns "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"

# Show/hide hidden files in Finder
abbr -a showhidden "defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
abbr -a hidehidden "defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

