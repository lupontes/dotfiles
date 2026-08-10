#!/usr/bin/env bash
# Clones the project repositories into REPO_ROOT (default ~/repos).
# GitHub repos use $GITHUB_TOKEN; Embrapa-internal repos use plain https
# (rely on the system credential helper / interactive auth — different hosts).
set -e

# Destination root for cloned projects (source machine used ~/git).
REPO_ROOT="${REPO_ROOT:-$HOME/repos}"
GIT_ROOT="$REPO_ROOT"
mkdir -p "$GIT_ROOT"

clone_github() {
  local repo="$1" dest="$GIT_ROOT/$1"
  if [ -d "$dest/.git" ]; then
    echo "already exists: $dest"
  else
    git clone --recurse-submodules \
      "https://lupontes:${GITHUB_TOKEN}@github.com/lupontes/$repo.git" "$dest"
    echo "cloned: $repo"
  fi
}

clone_url() {
  local url="$1" dest="$GIT_ROOT/$2"
  if [ -d "$dest/.git" ]; then
    echo "already exists: $dest"
  else
    echo "cloning (auth may be requested): $url"
    git clone "$url" "$dest" || echo "SKIPPED (auth/host unreachable): $2"
  fi
}

# --- GitHub (token auth) ---
clone_github "tip"             # monorepo with submodules tip-api / tip-web / tip-camunda
clone_github "projeto-publica"
clone_github "adubatec"

# --- Embrapa internal GitLab/Git (separate credentials) ---
clone_url "https://git.embrapa.io/publica/api.git"    "api"
clone_url "https://git.embrapa.io/publica/camunda.git" "camunda"
clone_url "https://git.embrapa.io/publica/web.git"     "web"
clone_url "https://git-cnpmf.nuvem.ti.embrapa.br/nti/prototipo-tip-cti.git" "prototipo-tip-cti"

echo ""
echo "repos.sh finished"
