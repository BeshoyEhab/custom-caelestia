function compress --description "Compress directory respecting .gitignore"
  set -l out archive.tar.gz
  set -l dir .

  if set -q argv[2]
    set out $argv[1]
    set dir $argv[2]
  else if set -q argv[1]
    if test -d "$argv[1]"
      set dir $argv[1]
      set out (string trim -c / -- "$dir").tar.gz
    else
      set out $argv[1]
    end
  end

  set -l common_excludes \
    --exclude=.git \
    --exclude=node_modules \
    --exclude=__pycache__ \
    --exclude=*.pyc \
    --exclude=.venv \
    --exclude=venv \
    --exclude=.env \
    --exclude=.DS_Store \
    --exclude=.idea \
    --exclude=.vscode \
    --exclude=.tox \
    --exclude=.mypy_cache \
    --exclude=.pytest_cache \
    --exclude=.ruff_cache \
    --exclude=target \
    --exclude=.next

  tar $common_excludes --exclude-vcs-ignores -cvzf "$out" "$dir"
end
