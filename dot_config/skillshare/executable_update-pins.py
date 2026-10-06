#!/usr/bin/env python3
"""Update selected public skill pins in the chezmoi seed, without applying them."""

import argparse
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
from urllib.parse import quote


SEED_RELATIVE_PATH = Path("dot_config/skillshare/metadata-seed.json")
FULL_SHA = re.compile(r"[0-9a-fA-F]{40}")
GITHUB_SOURCE = re.compile(
    r"(?:https://github\.com/|github\.com/)?"
    r"([A-Za-z0-9-]+)/([A-Za-z0-9_.-]+)"
    r"(?:/[A-Za-z0-9_.-]+)*/?"
)


def run_command(command):
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.strip() or str(exc)
        raise RuntimeError(f"{' '.join(command)} failed: {detail}") from exc
    return result.stdout.strip()


def default_seed_path():
    source_path = run_command(["chezmoi", "source-path"])
    if not source_path:
        raise ValueError("chezmoi source-path returned an empty path")
    return Path(source_path) / SEED_RELATIVE_PATH


def github_repo(source):
    match = GITHUB_SOURCE.fullmatch(source) if isinstance(source, str) else None
    if match is None:
        raise ValueError(f"Unsupported GitHub seed source: {source!r}")
    owner, repo = match.groups()
    if repo.endswith(".git"):
        repo = repo[:-4]
    if not repo or repo in (".", ".."):
        raise ValueError(f"Invalid GitHub repository in seed source: {source!r}")
    return f"{owner}/{repo}".lower()


def default_branch_head(repo):
    repository = json.loads(run_command(["gh", "api", f"repos/{repo}"]))
    branch = repository.get("default_branch") if isinstance(repository, dict) else None
    if not isinstance(branch, str) or not branch:
        raise ValueError(f"GitHub returned no default branch for {repo}")
    commit = json.loads(
        run_command(["gh", "api", f"repos/{repo}/commits/{quote(branch, safe='')}"])
    )
    sha = commit.get("sha") if isinstance(commit, dict) else None
    if not isinstance(sha, str) or FULL_SHA.fullmatch(sha) is None:
        raise ValueError(f"GitHub returned no full commit SHA for {repo}")
    return sha.lower()


def write_seed(seed_path, seed):
    mode = stat.S_IMODE(seed_path.stat().st_mode)
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=seed_path.parent,
            prefix=f".{seed_path.name}.", delete=False,
        ) as temporary:
            temporary_path = Path(temporary.name)
            json.dump(seed, temporary, indent=2)
            temporary.write("\n")
        temporary_path.chmod(mode)
        os.replace(temporary_path, seed_path)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def update_pins(seed_path, names, all_skills):
    with seed_path.open(encoding="utf-8") as file:
        seed = json.load(file)
    entries = seed.get("entries") if isinstance(seed, dict) else None
    if not isinstance(entries, dict):
        raise ValueError("Seed must contain an entries object")
    unknown = [name for name in names if name not in entries]
    if unknown:
        raise ValueError(f"Unknown skill relative path(s): {', '.join(unknown)}")
    selected = list(entries) if all_skills else list(dict.fromkeys(names))

    # Validate every selection before contacting GitHub or changing the seed.
    pins = []
    for name in selected:
        entry = entries[name]
        if not isinstance(entry, dict):
            raise ValueError(f"Seed entry for {name} must be an object")
        old_sha = entry.get("branch")
        if not isinstance(old_sha, str) or FULL_SHA.fullmatch(old_sha) is None:
            raise ValueError(f"Seed branch for {name} must be a full commit SHA")
        pins.append((name, github_repo(entry.get("source")), old_sha))

    # Stage all upstream results: a failed API call must leave the seed intact.
    heads = {}
    for _, repo, _ in pins:
        if repo not in heads:
            heads[repo] = default_branch_head(repo)

    changed = False
    for name, repo, old_sha in pins:
        new_sha = heads[repo]
        if old_sha.lower() != new_sha:
            entries[name]["branch"] = new_sha
            changed = True
    if changed:
        write_seed(seed_path, seed)

    for name, repo, old_sha in pins:
        new_sha = heads[repo]
        if old_sha.lower() == new_sha:
            print(f"{name}: unchanged ({old_sha})")
        else:
            print(f"{name}: {old_sha} -> {new_sha}")
            print(f"  https://github.com/{repo}/compare/{old_sha}...{new_sha}")
    if changed:
        print(f"Updated seed: {seed_path}")
        print("Review the comparisons before applying with chezmoi; nothing was installed or synced.")
    else:
        print("No pins changed.")


def main():
    parser = argparse.ArgumentParser(
        description="Update selected skill pins to GitHub default-branch HEADs in the dotfiles seed only.",
        epilog="No install, sync, or live metadata changes. Review the printed comparisons before applying.",
    )
    parser.add_argument("names", nargs="*", metavar="RELATIVE_NAME", help="seed skill paths, e.g. anthropic/pdf")
    parser.add_argument("--all", action="store_true", help="update every skill listed in the seed")
    parser.add_argument("--seed", type=Path, help="seed JSON path (default: chezmoi source-path/dot_config/skillshare/metadata-seed.json)")
    args = parser.parse_args()
    if args.all and args.names:
        parser.error("--all and explicit skill paths are mutually exclusive")
    if not args.all and not args.names:
        parser.error("specify one or more skill paths, or --all")
    try:
        seed_path = args.seed.expanduser() if args.seed is not None else default_seed_path()
        update_pins(seed_path, args.names, args.all)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
