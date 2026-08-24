---
name: github-review
description: >
  Manage GitHub pull request reviews using the `gh` CLI. Use this skill whenever
  the user asks to review a PR, leave review comments, approve or request changes,
  add inline/line comments to a review, create a pending review and submit it later,
  dismiss a review, or any PR review workflow beyond simple `gh pr review`. This
  skill is especially relevant when the user needs pending reviews, line-level
  comments, or multi-step review workflows — things `gh pr review` can't do alone.
  Also use when the user says things like "add a comment on line 42", "start a
  review but don't submit yet", "request changes on this PR", or "approve with
  comments".
---

# GitHub PR Review Skill

This skill covers GitHub pull request review operations using `gh api graphql`.
All reviews are created as pending first, with inline line comments, and only
submitted after the user confirms.

## Default behavior: always create pending reviews

Every review starts as **pending**. A pending review is a draft visible only to you
— it accumulates comments without notifying anyone. After creating the pending
review and adding all comments, give the user a link to the PR's "Files changed"
tab so they can inspect the pending comments in GitHub's UI, then ask whether they
want to submit it (and if so, as approve, request-changes, or comment).

Never submit a review without the user's explicit go-ahead. An accidentally
published review cannot be unpublished, and the user may want to edit comments in
GitHub's UI before submitting.

### What this means in practice

- Do not use `gh pr review` — it always submits immediately.
- Do not pass an `event` field in `addPullRequestReview` — that submits immediately.
- Do not use the REST `POST /repos/.../pulls/{n}/reviews` endpoint with a
  `comments[]` array — it auto-submits even without an `event` field.
- The only safe path is the **GraphQL pending workflow**: `addPullRequestReview`
  (omit `event`) → `addPullRequestReviewThread` for each comment → stop and ask
  the user → `submitPullRequestReview` only after confirmation.

### After creating a pending review

Once all comments are added, present the user with:

1. A link to the PR's "Files changed" tab:
   `https://github.com/{owner}/{repo}/pull/{number}/files`
   (the pending comments are visible there to the review author)
2. A summary of the comments you added (file, line, gist of each comment)
3. Ask: "Want me to submit this review? If so, as approve, request-changes, or
   comment?"

Only call `submitPullRequestReview` after the user confirms.

## Quick reference: what `gh` can and can't do natively

| Operation | Native `gh` support? | How |
|---|---|---|
| Approve a PR | Yes | `gh pr review --approve` |
| Request changes | Yes | `gh pr review --request-changes --body "..."` |
| Comment (no approval) | Yes | `gh pr review --comment --body "..."` |
| Create a **pending** review | No | GraphQL: `addPullRequestReview` (omit `event`) |
| Add **line comments** | No | GraphQL: `addPullRequestReviewThread` |
| Submit a pending review | No | GraphQL: `submitPullRequestReview` |
| List reviews | Partial | `gh pr view --json reviews` |
| Dismiss a review | No | GraphQL: `dismissPullRequestReview` |

For anything marked "No" above, use `gh api graphql` with the appropriate mutation.
See `references/graphql-recipes.md` for copy-paste-ready queries and mutations.

## Review workflow

Use the GraphQL API for all reviews. The `gh` CLI's `gh pr review` command always
submits immediately and cannot create pending reviews.

### Step 1: Get the PR node ID

```bash
gh pr view <PR> --json id --jq '.id'
```

This returns a node ID like `PR_kwDO...`. You need this for all GraphQL mutations.

### Step 2: Create a pending review

```bash
gh api graphql -f query='
  mutation($prId: ID!) {
    addPullRequestReview(input: {
      pullRequestId: $prId
    }) {
      pullRequestReview {
        id
        state
      }
    }
  }
' -f prId="<PR_NODE_ID>"
```

Omitting the `event` field creates the review in `PENDING` state. Save the returned
review `id` (format: `PRR_...`) — you need it for adding comments and submitting.

### Step 3: Add line comments

For each inline comment, use `addPullRequestReviewThread`:

```bash
gh api graphql -f query='
  mutation($reviewId: ID!, $body: String!, $path: String!, $line: Int!, $side: DiffSide!) {
    addPullRequestReviewThread(input: {
      pullRequestReviewId: $reviewId
      body: $body
      path: $path
      line: $line
      side: $side
    }) {
      thread { id }
    }
  }
' -f reviewId="<PRR_ID>" -f body="Comment text" -f path="src/main.go" -F line=42 -f side="RIGHT"
```

**Parameters:**
- `path` — File path relative to the repo root
- `line` — Line number in the diff hunk
- `side` — `RIGHT` for additions/unchanged lines, `LEFT` for deletions
- For multi-line comments, add `startLine` (Int) and optionally `startSide`
- For file-level comments (not tied to a line), set `subjectType: FILE` and omit `line`

### Step 4: Present the pending review to the user and ask before submitting

At this point the review is pending — visible only to you in the PR's "Files
changed" tab. Present the user with:

- Link: `https://github.com/{owner}/{repo}/pull/{number}/files`
- Summary of all comments added (file, line number, gist)
- Ask: "Want me to submit this review? If so, as approve, request-changes, or
  comment?"

### Step 5: Submit the review (only after user confirms)

```bash
gh api graphql -f query='
  mutation($reviewId: ID!, $event: PullRequestReviewEvent!, $body: String) {
    submitPullRequestReview(input: {
      pullRequestReviewId: $reviewId
      event: $event
      body: $body
    }) {
      pullRequestReview {
        state
      }
    }
  }
' -f reviewId="<PRR_ID>" -f event="<EVENT>" -f body="Overall review summary"
```

**Event values:** `APPROVE`, `REQUEST_CHANGES`, `COMMENT`

## Inspecting existing reviews

```bash
# List all reviews on a PR (reviewer, state, body)
gh pr view <PR> --json reviews --jq '.reviews[] | {author: .author.login, state: .state, body: .body}'

# List review comments (inline comments)
gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments --jq '.[] | {path: .path, line: .line, body: .body, user: .user.login}'
```

## Dismissing a review

```bash
gh api graphql -f query='
  mutation($reviewId: ID!, $message: String!) {
    dismissPullRequestReview(input: {
      pullRequestReviewId: $reviewId
      message: $message
    }) {
      pullRequestReview { state }
    }
  }
' -f reviewId="<PRR_ID>" -f message="Dismissing: issues have been addressed"
```

To get the review node ID for dismissal, query the PR's reviews:

```bash
gh api graphql -f query='
  query($prId: ID!) {
    node(id: $prId) {
      ... on PullRequest {
        reviews(last: 10) {
          nodes { id author { login } state }
        }
      }
    }
  }
' -f prId="<PR_NODE_ID>"
```

## Bulk line comments: use a temp file for complex comment bodies

When comment bodies contain special characters (like `?`, `'`, `{}`), passing them
inline on the command line will break in Fish shell and other shells due to glob
expansion and quoting. For bulk comments, write the GraphQL payload to a temp file
and use `--input`.

Since reviews must always start as pending, use `addPullRequestReviewThread` for
each comment after creating the pending review. For comments with simple bodies,
inline `-f` flags work fine. For comments with complex bodies, use a temp file per
call:

```bash
cat > /tmp/review-comment.json << 'EOF'
{
  "query": "mutation($reviewId: ID!, $body: String!, $path: String!, $line: Int!) { addPullRequestReviewThread(input: { pullRequestReviewId: $reviewId, body: $body, path: $path, line: $line, side: RIGHT }) { thread { id } } }",
  "variables": {
    "reviewId": "PRR_...",
    "body": "This token is never validated — what if it's expired?",
    "path": "src/auth.go",
    "line": 42
  }
}
EOF

gh api graphql --input /tmp/review-comment.json
```

For many comments, you can loop over a JSON array and write each to the temp file
before calling `gh api graphql --input`.

## Pitfalls to avoid

### Never submit without user confirmation

Reviews default to pending. Three things will accidentally submit:

1. Using `gh pr review` at all (it always submits)
2. Passing `event` in `addPullRequestReview` — omit it entirely
3. Using the REST reviews endpoint with a `comments[]` array — auto-submits even
   without an explicit `event` field

Always: `addPullRequestReview` (no event) → `addPullRequestReviewThread` per
comment → show the user the "Files changed" link → wait for confirmation →
only then `submitPullRequestReview`.

### Don't use the single-comment REST endpoint

The endpoint `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments` (for creating
a single review comment outside of a review) has a confusing `oneOf` schema with
different required fields depending on the sub-schema. It almost always results in
422 errors. Use the reviews endpoint with a `comments[]` array instead, or use the
GraphQL `addPullRequestReviewThread` mutation.

### Don't mix GraphQL node IDs with REST endpoints

GraphQL returns node IDs like `PRR_kwDO...`. REST endpoints require numeric IDs. If
you created a review via GraphQL and need to query its comments via REST, you need
the numeric ID — get it from `gh api repos/{owner}/{repo}/pulls/{number}/reviews`.

### Prefer inline comments over body-only reviews

When the user asks for a review with specific code feedback, post inline line
comments anchored to the relevant code — don't dump everything into the review body.
Inline comments are far more useful because they appear directly in the "Files
changed" tab next to the code. Use the pending review workflow (create → add line
comments → submit) or the bulk REST endpoint with `comments[]`.

## Other practical tips

- **`-F` for integers, `-f` for strings** — when passing GraphQL variables via
  `gh api graphql`, use `-F line=42` (uppercase F) for integer values and
  `-f body="text"` (lowercase f) for strings. Getting this wrong causes type errors.
- **Check for an existing pending review** before creating a new one. A user can only
  have one pending review per PR. Query with `gh pr view <PR> --json reviews` and
  look for `state: "PENDING"` from the current user.
- **The diff line number is not the file line number.** When adding line comments,
  `line` refers to the position in the diff, which corresponds to the line number
  shown in the "Files changed" tab on GitHub. For new/modified lines this matches
  the file line number on the RIGHT side; for deleted lines, it matches the old file
  line number on the LEFT side.
- When reviewing a PR programmatically, first run `gh pr diff <PR>` to see the
  changes, then formulate comments against specific paths and line numbers from that
  diff output.

## Reference files

- `references/graphql-recipes.md` — Complete, copy-paste-ready GraphQL queries and
  mutations for all review operations. Consult this when you need the exact query
  syntax or want to see all available input fields.
