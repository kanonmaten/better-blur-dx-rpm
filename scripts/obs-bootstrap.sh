#!/usr/bin/env bash
# One-time OBS + GitHub setup. Idempotent; safe to re-run.
#
#   OBS:    points home:kanonmaten/kwin-effects-better-blur-dx at this git
#           repo via <scmsync>, and creates its runservice token
#   GitHub: two webhooks (push -> rebuild, PR -> test build), "Allow
#           auto-merge", Actions may open PRs, and a ruleset on main that
#           requires the OBS build check
#
# Token secrets go straight from osc to gh and are never printed.
#
# PR builds reuse your existing OBS *workflow* token (the one claude-desktop
# uses). The GitHub PAT stored in it must be able to reach this repo with
# Commit statuses: read and write. If it is a fine-grained PAT limited to
# selected repositories, add kanonmaten/better-blur-dx-rpm to it first:
#   https://github.com/settings/personal-access-tokens
#
# Prereqs: osc configured for build.opensuse.org, gh logged in as the owner.
# Usage:   scripts/obs-bootstrap.sh
set -euo pipefail

OBS_USER="kanonmaten"
PROJ="home:$OBS_USER"
REPO="openSUSE_Tumbleweed"
PKG="kwin-effects-better-blur-dx"
GH_REPO="kanonmaten/better-blur-dx-rpm"
GIT_URL="https://github.com/$GH_REPO?subdir=packaging#main"
CHECK="OBS: $PKG - $REPO/x86_64"
OBS="https://build.opensuse.org"

command -v osc >/dev/null || { echo "osc not installed / not in PATH"; exit 1; }
command -v gh  >/dev/null || { echo "gh not installed / not in PATH"; exit 1; }

# Run osc once un-piped so a first-run login prompt is visible (later calls
# pipe osc output, which would swallow the prompt).
osc whois
gh auth status >/dev/null

echo "==> Checking $PROJ has a $REPO repository"
osc meta prj "$PROJ" | grep -q "<repository name=\"$REPO\"" \
  || { echo "    missing: add it in the OBS web UI (Repositories -> Add from a Distribution)"; exit 1; }
echo "    ok"

echo "==> Pointing $PROJ/$PKG at git via <scmsync>"
if osc meta pkg "$PROJ" "$PKG" 2>/dev/null | grep -qF "<scmsync>$GIT_URL</scmsync>"; then
  echo "    already set"
else
  osc meta pkg "$PROJ" "$PKG" -F - <<XML
<package name="$PKG" project="$PROJ">
  <title>Better Blur DX KWin effect</title>
  <description>Fork of the KWin blur effect with force blur and more, built from https://github.com/xarblu/kwin-effects-better-blur-dx. Packaging: $GIT_URL</description>
  <scmsync>$GIT_URL</scmsync>
  <!-- Home projects default to no debuginfo, and then rpm doesn't strip the
       plugins (rpmlint: unstripped-binary-or-object). -->
  <debuginfo>
    <enable/>
  </debuginfo>
</package>
XML
  echo "    set"
fi

# Print "<id> <secret>" for the first token matching operation (+ package).
token_field() {  # $1 operation, $2 package ("" = any)
  osc token | awk -v op="$1" -v pkg="$2" '
    /^ID /        { id=$3 }
    /^String /    { s=$3 }
    /^Operation / { o=$3 }
    /^Package /   { p=$3 }
    /^$/          { if (o==op && (pkg=="" || p==pkg) && !done) { print id, s; done=1 } id=s=o=p="" }
    END           { if (o==op && (pkg=="" || p==pkg) && !done) print id, s }
  '
}

echo "==> runservice token for $PROJ/$PKG"
read -r rs_id rs_secret <<<"$(token_field runservice "$PKG")"
if [ -z "${rs_id:-}" ]; then
  osc token --create --operation runservice "$PROJ" "$PKG" >/dev/null
  read -r rs_id rs_secret <<<"$(token_field runservice "$PKG")"
  echo "    created (id $rs_id)"
else
  echo "    exists (id $rs_id)"
fi
[ -n "${rs_secret:-}" ] || { echo "    could not read the runservice token"; exit 1; }

echo "==> Existing workflow token (for PR builds)"
read -r wf_id wf_secret <<<"$(token_field workflow "")"
[ -n "${wf_id:-}" ] || { echo "    none found. Create one with:  osc token --create --operation workflow --scm-token <GITHUB_PAT>"; exit 1; }
echo "    using id $wf_id"

add_hook() {  # $1 url, $2 secret, $3 event
  if gh api "repos/$GH_REPO/hooks" --jq '.[].config.url' | grep -qxF "$1"; then
    echo "    $3 hook already present"
  else
    gh api "repos/$GH_REPO/hooks" --silent \
      -f name=web -F active=true -f "events[]=$3" \
      -f "config[url]=$1" -f "config[content_type]=json" \
      -f "config[secret]=$2" -f "config[insecure_ssl]=0"
    echo "    $3 hook added"
  fi
}

echo "==> GitHub webhooks on $GH_REPO"
add_hook "$OBS/trigger/webhook?id=$rs_id"  "$rs_secret" push
add_hook "$OBS/trigger/workflow?id=$wf_id" "$wf_secret" pull_request
unset rs_secret wf_secret

echo "==> Repo settings: auto-merge, delete merged branches, Actions may open PRs"
gh api -X PATCH "repos/$GH_REPO" --silent -F allow_auto_merge=true -F delete_branch_on_merge=true
gh api -X PUT "repos/$GH_REPO/actions/permissions/workflow" --silent \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
echo "    ok"

echo "==> Ruleset on main requiring \"$CHECK\""
if gh api "repos/$GH_REPO/rulesets" --jq '.[].name' | grep -qx "main"; then
  echo "    already present"
else
  # Any source (no integration_id): OBS posts statuses with the PAT, not as
  # an App. Not strict, or overlapping bump PRs stall. No required reviews,
  # or bot PRs never merge. Repo admins bypass, so you can still push.
  gh api "repos/$GH_REPO/rulesets" --silent --input - <<JSON
{
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" } ],
  "rules": [
    { "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [ { "context": "$CHECK" } ] } }
  ]
}
JSON
  echo "    created"
fi

cat <<NEXT

==> Done. Check it with:
     osc results $PROJ $PKG
     osc api /source/$PROJ/$PKG/_scmsync.obsinfo
   Force a re-sync from git any time with:
     osc service remoterun $PROJ $PKG
NEXT
