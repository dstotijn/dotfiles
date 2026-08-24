# GraphQL Recipes for PR Reviews

Complete queries and mutations for managing pull request reviews via `gh api graphql`.

## Table of Contents

- [Get PR node ID](#get-pr-node-id)
- [Create pending review](#create-pending-review)
- [Create review with inline comments in one shot](#create-review-with-inline-comments-in-one-shot)
- [Add line comment to pending review](#add-line-comment-to-pending-review)
- [Add multi-line comment](#add-multi-line-comment)
- [Add file-level comment](#add-file-level-comment)
- [Submit pending review](#submit-pending-review)
- [List reviews on a PR](#list-reviews-on-a-pr)
- [List comments on a specific review](#list-comments-on-a-specific-review)
- [Dismiss a review](#dismiss-a-review)
- [Delete a pending review](#delete-a-pending-review)
- [Reply to a review thread](#reply-to-a-review-thread)

---

## Get PR node ID

```bash
# Quick — just the ID
gh pr view <PR> --json id --jq '.id'

# With context — ID plus key metadata
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        id
        title
        headRefOid
        baseRefName
        headRefName
      }
    }
  }
' -f owner="OWNER" -f repo="REPO" -F number=123
```

## Create pending review

Omit `event` to create in PENDING state.

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
' -f prId="PR_NODE_ID"
```

Returns `id` in format `PRR_...` — save this for subsequent operations.

**With a body (review summary, still pending):**

```bash
gh api graphql -f query='
  mutation($prId: ID!, $body: String!) {
    addPullRequestReview(input: {
      pullRequestId: $prId
      body: $body
    }) {
      pullRequestReview {
        id
        state
      }
    }
  }
' -f prId="PR_NODE_ID" -f body="Review summary goes here"
```

## Create review with inline comments in one shot

You can create a review and add comments atomically using the `threads` field.
This is useful when you already know all the comments upfront.

```bash
gh api graphql -f query='
  mutation($prId: ID!) {
    addPullRequestReview(input: {
      pullRequestId: $prId
      event: REQUEST_CHANGES
      body: "Several issues to address."
      threads: [
        {
          path: "src/auth.go"
          line: 42
          side: RIGHT
          body: "This token is never validated."
        },
        {
          path: "src/auth.go"
          line: 58
          side: RIGHT
          body: "Missing error return here."
        }
      ]
    }) {
      pullRequestReview {
        id
        state
      }
    }
  }
' -f prId="PR_NODE_ID"
```

Note: `threads` values are inline in the query (not passed as variables) because
`gh api graphql` doesn't support complex nested variable types easily. For dynamic
comments, use the pending review workflow instead (create review, then add threads
one by one).

## Add line comment to pending review

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
      thread {
        id
        comments(first: 1) {
          nodes { body }
        }
      }
    }
  }
' -f reviewId="PRR_ID" -f body="Comment text" -f path="src/main.go" -F line=42 -f side="RIGHT"
```

**`side` values:**
- `RIGHT` — Comment on the new version of the file (additions, unchanged lines)
- `LEFT` — Comment on the old version (deleted lines)

## Add multi-line comment

Use `startLine` and optionally `startSide` to highlight a range of lines:

```bash
gh api graphql -f query='
  mutation($reviewId: ID!, $body: String!, $path: String!, $line: Int!, $startLine: Int!) {
    addPullRequestReviewThread(input: {
      pullRequestReviewId: $reviewId
      body: $body
      path: $path
      line: $line
      side: RIGHT
      startLine: $startLine
      startSide: RIGHT
    }) {
      thread { id }
    }
  }
' -f reviewId="PRR_ID" -f body="This whole block should be refactored" -f path="src/handler.go" -F line=50 -F startLine=40
```

`startLine` must be less than or equal to `line`. The highlighted range is
`startLine..line` inclusive.

## Add file-level comment

For comments about a file as a whole, not tied to a specific line:

```bash
gh api graphql -f query='
  mutation($reviewId: ID!, $body: String!, $path: String!) {
    addPullRequestReviewThread(input: {
      pullRequestReviewId: $reviewId
      body: $body
      path: $path
      subjectType: FILE
    }) {
      thread { id }
    }
  }
' -f reviewId="PRR_ID" -f body="This file needs a license header" -f path="src/new_module.go"
```

## Submit pending review

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
        url
      }
    }
  }
' -f reviewId="PRR_ID" -f event="REQUEST_CHANGES" -f body="Please address the inline comments."
```

**Event values:**
- `APPROVE` — Approve the PR
- `REQUEST_CHANGES` — Block merging until issues are resolved
- `COMMENT` — Leave feedback without explicit approval or rejection

## List reviews on a PR

```bash
gh api graphql -f query='
  query($prId: ID!) {
    node(id: $prId) {
      ... on PullRequest {
        reviews(last: 20) {
          nodes {
            id
            author { login }
            state
            body
            submittedAt
          }
        }
      }
    }
  }
' -f prId="PR_NODE_ID"
```

**Review states:** `PENDING`, `COMMENTED`, `APPROVED`, `CHANGES_REQUESTED`, `DISMISSED`

## List comments on a specific review

```bash
gh api graphql -f query='
  query($reviewId: ID!) {
    node(id: $reviewId) {
      ... on PullRequestReview {
        comments(first: 50) {
          nodes {
            path
            position
            body
            diffHunk
          }
        }
      }
    }
  }
' -f reviewId="PRR_ID"
```

## Dismiss a review

```bash
gh api graphql -f query='
  mutation($reviewId: ID!, $message: String!) {
    dismissPullRequestReview(input: {
      pullRequestReviewId: $reviewId
      message: $message
    }) {
      pullRequestReview {
        state
      }
    }
  }
' -f reviewId="PRR_ID" -f message="Issues have been addressed in latest push"
```

## Delete a pending review

Deletes a review that hasn't been submitted yet. This removes all pending comments.

```bash
gh api graphql -f query='
  mutation($reviewId: ID!) {
    deletePullRequestReview(input: {
      pullRequestReviewId: $reviewId
    }) {
      pullRequestReview {
        state
      }
    }
  }
' -f reviewId="PRR_ID"
```

## Reply to a review thread

To reply to an existing review comment thread (e.g. responding to feedback):

```bash
gh api graphql -f query='
  query($prId: ID!) {
    node(id: $prId) {
      ... on PullRequest {
        reviewThreads(first: 50) {
          nodes {
            id
            isResolved
            comments(first: 1) {
              nodes { body path }
            }
          }
        }
      }
    }
  }
' -f prId="PR_NODE_ID"
```

Then reply to a specific thread:

```bash
gh api graphql -f query='
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {
      pullRequestReviewThreadId: $threadId
      body: $body
    }) {
      comment { body }
    }
  }
' -f threadId="PRRT_ID" -f body="Good point, fixed in the latest commit."
```
