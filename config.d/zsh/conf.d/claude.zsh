alias claude='claude --dangerously-skip-permissions'
npm-add-safe() {
  claude --allow-dangerously-skip-permissions -p "please checkout the git repo for npm package $1, audit the code and it's dependencies, and if it seems reasonable, run npm add $1. You are NOT being run interactively, if the package seems safe, add it, do not ask questions."
}