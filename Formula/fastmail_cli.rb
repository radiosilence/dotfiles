# frozen_string_literal: true

# Homebrew formula for FastmailCli - a command-line interface for Fastmail using JMAP API
class FastmailCli < Formula
  desc 'Command-line interface for Fastmail using JMAP API'
  homepage 'https://github.com/radiosilence/dotfiles'
  url 'https://github.com/radiosilence/dotfiles/archive/refs/heads/main.tar.gz'
  version '0.1.0'
  sha256 ''
  license 'MIT'
  head 'https://github.com/radiosilence/dotfiles.git', branch: 'main'

  depends_on 'go' => :build

  def install
    cd 'packages/fastmail-cli' do
      system 'go', 'build', *std_go_args(ldflags: '-s -w'), '-o', bin / 'fastmail-cli', 'main.go'
    end

    # Install shell completions if they exist
    completion_dir = buildpath / 'fastmail-cli/config/fish/completions'
    return unless completion_dir.exist?

    fish_completion.install completion_dir / 'fastmail-cli.fish'
  end

  test do
    assert_match 'fastmail-cli', shell_output("#{bin}/fastmail-cli --help")
  end
end
