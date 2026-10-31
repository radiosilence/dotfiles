# Infra — cloud, orchestration, DevOps
tap 'hashicorp/tap'

brew 'awscli'
brew 'aws-sso-util'
brew 'cf-terraforming'
# watchman replaced by watchwoman — see github:radiosilence/watchwoman
brew 'qemu'
brew 'ios-deploy'
# macOS only via brew: vfox-gcloud's env hook probes for Python on every
# mise hook-env, ~100ms per shell start and directory change.
cask 'gcloud-cli'
