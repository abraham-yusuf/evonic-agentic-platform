#!/usr/bin/env python3
"""
setup_evonic.py — Initialise Evonic Docker Kit for GitHub + Agentic Platform

Run ONCE from your local machine (not workspace — workspace lacks Docker):

    python3 setup_evonic.py --pat YOUR_GITHUB_PAT

What it does:
  1. Authenticate gh CLI
  2. Create GitHub repo (if it doesn't exist)
  3. Copy Docker kit + Evonic source to the repo
  4. Push to GitHub (git push triggers GitHub Actions CI automatically)
  5. Trigger first build via workflow_dispatch
  6. Print the final ghcr.io image URL for Agentic Platform

After this runs, GitHub Actions will build ~5 min and push to:
  ghcr.io/USERNAME/evonic-agentic-platform:latest
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.request
import urllib.error
import base64


# ── Config ──────────────────────────────────────────────────────────────────
GITHUB_USER = "abraham-yusuf"
REPO_NAME = "evonic-agentic-platform"
DESCRIPTION = "Docker Sandbox Kit for Evonic Agentic AI Platform (Agentic Platform Deploy)"
GHCR_IMAGE = f"ghcr.io/{GITHUB_USER}/{REPO_NAME}"
WORKFLOW_FILE = ".github/workflows/build-push.yml"


# ── Helpers ─────────────────────────────────────────────────────────────────

def run(cmd: list[str], check=True, capture=True, input_data=None) -> str:
    """Run shell command, return stdout."""
    print(f"  $ {' '.join(cmd[:4])}...")
    kwargs = dict(capture_output=capture, text=True)
    if input_data:
        kwargs["input"] = input_data
    result = subprocess.run(cmd, **kwargs)
    if check and result.returncode != 0:
        print(f"  ❌ FAILED: {result.stderr or result.stdout}")
        sys.exit(1)
    return result.stdout.strip()


def gh_api(endpoint: str, token: str, method="GET", data=None):
    """Call GitHub REST API."""
    url = f"https://api.github.com{endpoint}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read()) if resp.status not in (204,) else None
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"  ❌ GitHub API error {e.code}: {body}")
        return None


def ensure_repo_exists(token: str) -> str:
    """Create the GitHub repo if it doesn't exist. Returns repo clone URL."""
    # Check if repo exists
    result = gh_api(f"/repos/{GITHUB_USER}/{REPO_NAME}", token)
    if result is not None:
        print("  ✓ Repository already exists")
        return f"https://{GITHUB_USER}:{token}@github.com/{GITHUB_USER}/{REPO_NAME}.git"

    # Create it
    print("  → Creating new GitHub repository...")
    result = gh_api(
        f"/user/repos",
        token,
        method="POST",
        data={
            "name": REPO_NAME,
            "description": DESCRIPTION,
            "private": False,
            "auto_init": False,
            "has_wiki": False,
            "has_projects": False,
        },
    )
    if result is None:
        print("  ❌ Failed to create repository")
        sys.exit(1)
    print(f"  ✓ Created repo: {result.get('html_url')}")
    return f"https://{GITHUB_USER}:{token}@github.com/{GITHUB_USER}/{REPO_NAME}.git"


def trigger_workflow(token: str, tag="latest"):
    """Trigger the build workflow via workflow_dispatch."""
    print("  → Triggering GitHub Actions build...")
    result = gh_api(
        f"/repos/{GITHUB_USER}/{REPO_NAME}/actions/workflows/build-push.yml/dispatches",
        token,
        method="POST",
        data={"ref": "main", "inputs": {"tag": tag}},
    )
    if result is None:
        print("  ⚠️  Could not auto-trigger workflow.")
        print("     Manually trigger at: "
              f"https://github.com/{GITHUB_USER}/{REPO_NAME}/actions")
    else:
        print("  ✓ Workflow triggered! Build will start in ~1 min.")
    return result


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Setup Evonic Docker Kit for GitHub + Agentic Platform"
    )
    parser.add_argument(
        "--pat",
        required=True,
        help="GitHub Personal Access Token (classic) with repo + packages scopes",
    )
    parser.add_argument(
        "--src",
        default="/workspace/evonic",
        help="Path to Evonic source (default: /workspace/evonic)",
    )
    parser.add_argument(
        "--kit",
        default="/workspace/evonic-docker-kit",
        help="Path to Docker kit (default: /workspace/evonic-docker-kit)",
    )
    args = parser.parse_args()

    token = args.pat.strip()
    clone_dir = f"/tmp/{REPO_NAME}"
    evonic_src = args.src.rstrip("/")
    kit_dir = args.kit.rstrip("/")

    print()
    print("═" * 60)
    print("  Evonic Docker Kit — GitHub Setup")
    print("═" * 60)
    print(f"  GitHub user  : {GITHUB_USER}")
    print(f"  Repo name    : {REPO_NAME}")
    print(f"  Evonic src   : {evonic_src}")
    print(f"  Docker kit   : {kit_dir}")
    print(f"  Target image : {GHCR_IMAGE}:latest")
    print()

    # ── Step 1: Verify PAT ─────────────────────────────────────────────────
    print("▶ Step 1: Verify GitHub PAT...")
    user_info = gh_api("/user", token)
    if user_info is None:
        print("  ❌ Invalid PAT or network error")
        print("  Make sure your PAT has: repo + write:packages scopes")
        sys.exit(1)
    print(f"  ✓ Authenticated as: {user_info.get('login')} ({user_info.get('name', '')})")

    # ── Step 2: Ensure repo exists ─────────────────────────────────────────
    print("\n▶ Step 2: Ensure GitHub repo exists...")
    repo_url = ensure_repo_exists(token)

    # ── Step 3: Clone repo ─────────────────────────────────────────────────
    print("\n▶ Step 3: Clone repo to temp dir...")
    if os.path.exists(clone_dir):
        shutil.rmtree(clone_dir)
    run(["git", "clone", repo_url.replace(f"{token}@", ""), clone_dir])

    # ── Step 4: Copy Evonic source + Docker kit ────────────────────────────
    print("\n▶ Step 4: Copy Evonic source + Docker kit to repo...")

    # Copy Docker kit files
    for item in os.listdir(kit_dir):
        src = os.path.join(kit_dir, item)
        dst = os.path.join(clone_dir, item)
        if os.path.isdir(src):
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Copy Evonic source (exclude heavy/generated dirs)
    exclude_dirs = {".git", ".venv", "node_modules", "__pycache__",
                    "data", "logs", "state", ".venv", "venv",
                    "shared", "unit_tests", "evaluator", "custom_tests",
                    ".egg-info", "build", "dist", "logs", "state",
                    "node_modules", ".mypy_cache", ".pytest_cache"}

    evonic_dest = os.path.join(clone_dir, "evonic-src")
    os.makedirs(evonic_dest, exist_ok=True)

    for item in os.listdir(evonic_src):
        if item in exclude_dirs:
            continue
        src = os.path.join(evonic_src, item)
        dst = os.path.join(evonic_dest, item)
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        else:
            shutil.copy2(src, dst)

    print("  ✓ Copied Evonic source + Docker kit")

    # ── Step 5: Commit & Push ──────────────────────────────────────────────
    print("\n▶ Step 5: Commit & push to GitHub...")
    os.chdir(clone_dir)

    # Create .gitignore (exclude token from being tracked)
    gitignore = """
# GitHub Actions secrets — never commit
GHCR_TOKEN.txt
*.token
.env
"""
    with open(".gitignore", "w") as f:
        f.write(gitignore.strip() + "\n")

    run(["git", "add", "."])
    run(["git", "commit", "-m",
         "feat: Evonic Docker Kit + GitHub Actions CI"])

    # Check if origin already has a branch
    run(["git", "push", "-u", "origin", "main", "--force"])
    print("  ✓ Pushed to GitHub!")

    # ── Step 6: Trigger Build ──────────────────────────────────────────────
    print("\n▶ Step 6: Trigger GitHub Actions build...")
    trigger_workflow(token, tag="latest")

    # ── Step 7: Done ───────────────────────────────────────────────────────
    print()
    print("═" * 60)
    print("  ✅ SETUP COMPLETE!")
    print("═" * 60)
    print()
    print(f"  📦 Image URL (for Agentic Platform):")
    print(f"     {GHCR_IMAGE}:latest")
    print()
    print(f"  🔗 GitHub repo:")
    print(f"     https://github.com/{GITHUB_USER}/{REPO_NAME}")
    print()
    print(f"  ⚡ GitHub Actions build:")
    print(f"     https://github.com/{GITHUB_USER}/{REPO_NAME}/actions")
    print()
    print("  ⏱️  Build takes ~5 min. Wait for 'Build and Push' to finish.")
    print()
    print("  Next step: paste this into Agentic Platform:")
    print(f"     {GHCR_IMAGE}:latest")
    print()


if __name__ == "__main__":
    main()
