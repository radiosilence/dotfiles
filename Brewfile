# frozen_string_literal: true

# Role-based Brewfile — see dotfiles-roles.template for available roles.
# Create dotfiles-roles (next to this file) with one role per line to activate.
# Without a roles file, only core packages are installed.

dotfiles_dir = File.dirname(File.realpath(__FILE__))
roles_file = File.join(dotfiles_dir, 'dotfiles-roles')
roles = if File.exist?(roles_file)
  File.readlines(roles_file).map(&:strip).reject { |l| l.empty? || l.start_with?('#') }
else
  ['core']
end

cask_args require_sha: true

# Taps used by core
tap 'buo/cask-upgrade'

# Core — always loaded
brewfiles_dir = File.join(dotfiles_dir, 'brewfiles.d')
eval(File.read(File.join(brewfiles_dir, 'core.rb')))

# Role-based includes
roles.each do |role|
  next if role == 'core' # already loaded above
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
