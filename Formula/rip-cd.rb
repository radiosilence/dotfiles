class RipCd < Formula
  desc 'CD ripper with metadata management and strong typing'
  homepage 'https://github.com/radiosilence/dotfiles'
  url 'https://github.com/radiosilence/dotfiles/archive/refs/heads/main.tar.gz'
  version '2.0.0'
  license 'MIT'
  head 'https://github.com/radiosilence/dotfiles.git', branch: 'main'

  depends_on 'go' => :build
  depends_on 'task' => :build

  def install
    cd 'packages/rip-cd' do
      system 'task', 'build'
      bin.install '../../bin/rip-cd'
    end
  end

  test do
    assert_match "rip-cd v#{version}", shell_output("#{bin}/rip-cd version")

    # Test template generation
    system bin / 'rip-cd', 'generate', 'template', '--workspace', testpath / 'test-workspace'
    assert_predicate testpath / 'test-workspace/metadata/template.yaml', :exist?

    # Test schema generation
    system bin / 'rip-cd', 'generate', 'schema', '--workspace', testpath / 'test-workspace'
    assert_predicate testpath / 'test-workspace/schemas/cd-metadata-schema.json', :exist?

    # Test validation
    system bin / 'rip-cd', 'validate', testpath / 'test-workspace/metadata/template.yaml', '--workspace',
           testpath / 'test-workspace'
  end
end
