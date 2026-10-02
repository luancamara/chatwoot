# Automatic grammar revision audit

Automatic composer revisions are recorded in `captain_message_revisions`, independently of Langfuse and application log level. This audit makes changes to agent drafts inspectable; it does not add semantic validation or recover drafts from before its deployment.

Each `auto_fix_grammar` request stores the authenticated account and agent, conversation, HTTP request ID, original draft, raw model output, selected response, outcome/reason, model, prompt SHA-256, token usage when available, and elapsed milliseconds. The record is created before the model call. Interrupted requests can remain `pending`; this is not evidence that a message was sent.

The response includes `revision_id`. The composer forwards it as `content_attributes.grammar_revision_id` when creating messages, including text/attachment splits. The message builder verifies that the record belongs to the same account, conversation and sending user. Delivery retries preserve the ID. Only this identifier appears in normal message payloads; the original draft and raw model output are not copied into public content attributes.

## Inspect a conversation

An account administrator can request:

```text
GET /api/v1/accounts/{account_id}/captain/tasks/revisions?conversation_display_id={display_id}
```

Use normal authenticated account API headers. Agents and users outside the account cannot read the audit. Results contain up to 50 revisions, newest first; use `before_id` with the last revision ID for the next page.

Compare `original_content`, `revised_content` and `selected_content` with each entry in `messages`. The linked messages include the persisted content, ID, current delivery status, channel source ID and creation time. A created message is not proof of delivery: consult its status. An empty `messages` list means there is no currently linked message, which can happen after cancellation, a failed HTTP response, message deletion, or use of an older browser bundle. It does not imply that the revision was sent.

Outcomes:

- `pending`: request was recorded but has not finalized.
- `accepted`: changed model output passed the current guard.
- `unchanged`: model returned the original draft.
- `rejected`: model output was discarded; the original was selected.
- `skipped`: there was no revisable text, such as a URL-only message.
- `error`: revision was unavailable or failed; the original was selected.

An `accepted` outcome does not prove that names, locations or commercial facts were preserved. The current guard validates language and protected fragments; consult the original and raw output when investigating semantic changes.

## Retention and rollout

`Internal::RemoveExpiredMessageRevisionsJob` runs daily at 03:15 UTC and deletes audit rows older than 30 days. It preserves messages. Deleting an account or conversation cascades to its audit records. After retention expires, a message may still contain the historical revision ID but its audit content is no longer available.

Run migration `20260912210000` before deploying the new web and worker processes. No existing records are backfilled. Refresh browser tabs to load the composer that forwards revision IDs. Existing manual rewrite operations retain their contracts and do not create automatic-revision audit records.

If audit persistence is unavailable, the rewrite request fails and the existing composer fallback sends the original draft. Do not interpret a healthy LLM endpoint or a pending audit record as proof that auditing is functioning: verify a persisted completed record and a linked test message in an isolated test environment.
