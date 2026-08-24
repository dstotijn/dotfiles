---
name: hindsight
description: Selective, explicit cross-session memory through the configured Hindsight CLI. Use when a non-trivial task may depend on a past preference, decision, confirmed workaround, or earlier failure; when the user asks what was previously decided; or when the user explicitly asks to remember something. Retain only durable, non-sensitive, future-useful knowledge. Never automatically store conversations, source files, logs, secrets, or routine progress.
---

# Hindsight Memory

Use the configured `hindsight` CLI for deliberate, agent-initiated memory calls. Do not install hooks, capture sessions automatically, or send every interaction to Hindsight.

Briefly tell the user before calling Hindsight and explain why. Do not include sensitive details in that notice.

Pass `-o json` to read commands so their output is clean and parseable.

## Recall selectively

Recall when a non-trivial task is likely to benefit from a past:

- user preference or working convention;
- project or architecture decision and its rationale;
- confirmed workaround, bug cause, or fix;
- failure or lesson that could prevent repeated work;
- fact the user explicitly asks you to remember or retrieve.

Use a focused query:

```bash
hindsight -o json memory recall default "user preferences relevant to this task"
hindsight -o json memory recall default "previous decisions and confirmed problems in this area"
```

Use reflection only when synthesis across several memories would materially help:

```bash
hindsight -o json memory reflect default "What past decisions or lessons should guide this task?"
```

Do not recall for trivial questions, or when the current repository, documentation, or live system is the authoritative source. Treat recalled information as fallible and potentially stale; verify it before relying on it.

## Fetch exact source text when needed

Recall and reflection return extracted facts and can omit exact values. When a result points to a stored document and an exact literal is necessary, fetch that document:

```bash
hindsight -o json document get default <document_id>
hindsight -o json document list default
```

Read `original_text`, but expose or use only the part needed for the task.

## Retain deliberately

Retain only when the user explicitly asks, or when you learn something durable, confirmed, non-sensitive, and likely to save future work:

- a stable user preference;
- a confirmed technical decision and its rationale;
- a proven procedure or workaround;
- a verified bug cause and fix;
- a non-obvious constraint that will matter again.

Write a concise, self-contained memory containing the useful fact, why it matters, and the confirmed outcome. Include exact values only when they are necessary and safe to persist.

```bash
hindsight memory retain default "The user prefers explicit Hindsight recall and retention calls; do not enable automatic transcript or Git ingestion." --context preferences
hindsight memory retain default "The build requires Node 20 because Node 18 fails with the confirmed ESM loader incompatibility." --context learnings
hindsight memory retain default "Run the integration suite with NODE_ENV=test; this selects the isolated test configuration." --context procedures
```

Never retain:

- complete conversations, transcripts, or session dumps;
- raw source files, patches, logs, command output, or tool results;
- routine progress or facts that are easy to recover from an authoritative source;
- speculation, unverified hypotheses, or transient state;
- passwords, API keys, tokens, credentials, private keys, or `.env` contents;
- personal or customer data unless the user explicitly approves that specific retention.

If sensitivity or future value is ambiguous, ask before retaining. Never send a broad payload merely because Hindsight can extract facts from it.

## If Hindsight is unavailable

Do not start Hindsight, Docker, or another service solely for an optional memory call. Continue without memory and briefly report that Hindsight was unavailable. If memory is essential because the user explicitly requested it, explain the blocker.
