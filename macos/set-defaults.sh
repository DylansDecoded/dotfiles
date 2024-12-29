# Set MacOS preferences - Borrowed from https://github.com/mathiasbynens/dotfiles/blob/master/.macos

# Close any open System Preferences panes, to prevent them from overriding


# chflag settings
# Show the ~/Library folder
chflags nohidden ~/Library

# Set Dock to no-hide and left
defaults write com.apple.dock orientation left
defaults write com.apple.dock autohide -bool false

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false
print_success "Are you sure you want to open this app dialog disabled."

# Disable press-and-hold for keys in favor of key repeat.
defaults write -g ApplePressAndHoldEnabled -bool false

# Use AirDrop over every interface. srsly this should be a default.
defaults write com.apple.NetworkBrowser BrowseAllInterfaces 1

# Always open everything in Finder's list view. This is important.
defaults write com.apple.Finder FXPreferredViewStyle Nlsv

# Show the ~/Library folder.
chflags nohidden ~/Library

# Set a really fast key repeat.
defaults write NSGlobalDomain KeyRepeat -int 1

# Set the Finder prefs for showing a few different volumes on the Desktop.
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Set Screenshots folder to ~/Pictures/Screenshots
mkdir -p ~/Pictures/Screenshots
defaults write com.apple.screencapture location ~/Pictures/Screenshots
