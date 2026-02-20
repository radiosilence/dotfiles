# frozen_string_literal: true

# Role-based Brewfile — see dotfiles-roles.yml.template for available roles.
# Create dotfiles-roles.yml (next to this file) to activate roles.
# Without a roles file, only core packages are installed.

require 'yaml'

dotfiles_dir = File.dirname(File.realpath(__FILE__))
roles_file = File.join(dotfiles_dir, 'dotfiles-roles.yml')
roles = if File.exist?(roles_file)
  config = YAML.safe_load(File.read(roles_file)) || {}
  config.fetch('roles', nil) || []
else
  []
end

cask_args require_sha: true

# Taps used by core
tap 'buo/cask-upgrade'

# Core — always loaded
brewfiles_dir = File.join(dotfiles_dir, 'brewfiles.d')
eval(File.read(File.join(brewfiles_dir, 'core.rb')))

# Role-based includes
roles.each do |role|
  role_file = File.join(brewfiles_dir, "#{role}.rb")
  if File.exist?(role_file)
    eval(File.read(role_file))
  else
    $stderr.puts "\e[33m  ! unknown brew role '#{role}', skipping\e[0m"
  end
end

# Machine-local overrides (not committed)
local_brewfile = File.join(dotfiles_dir, 'Brewfile.local')
eval(File.read(local_brewfile)) if File.exist?(local_brewfile)
