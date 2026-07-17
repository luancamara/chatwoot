# Silent Conversation Risk Monitor

## Context

The existing WhatsApp triage behaves like an operational bot: it sends menus and acknowledgements, changes conversation status, team and assignee, schedules escalations, and prevents complaints from being transferred before resolution. In practice, those public messages can arrive while a person is already talking to the customer, which makes the conversation confusing. Its installation-wide JSON configuration is also unsuitable for account administrators.

Captain is the appropriate conversational layer. The custom component should instead be a silent safety net that observes customer messages and calls management attention to complaints or critical risk without taking control of the conversation.

## Goals

- Never send a public message to the customer.
- Never change conversation status, priority, team, human assignee, or Captain assignment.
- Never block transfers or other agent actions.
- Detect complaints and critical situations from incoming public customer messages.
- Apply configured complaint and critical-risk labels.
- Create an internal private note mentioning a configured management team.
- Notify only once for the same risk level in an incident, with one additional alert if a complaint becomes critical.
- Operate independently of Captain and coexist with a Captain assistant on the same inbox.
- Provide an account settings page; routine configuration must not require JSON or Super Admin access.
- Initially enable the monitor only for Madeira Mania account 4, inbox 62.

## Non-goals

- Answering customers or presenting a menu.
- Routing sales, finance, after-sales, or general conversations.
- Assigning complaints to management.
- Replacing Captain's knowledge, guidelines, scenarios, handoff, or conversational behavior.
- General-purpose automatic labeling for products, campaigns, or customer profiles; Captain already has that responsibility.
- Building a visual automation engine.

## Chosen approach

Build an asynchronous, inbox-scoped risk monitor that is not an `AgentBot` and does not occupy the inbox bot slot. It listens to incoming public messages, debounces message bursts, classifies only management risk, applies labels, and writes a private team mention.

This approach is preferable to a Captain-only tool because it continues monitoring conversations that Captain does not handle. It is preferable to keyword-only automation because it can evaluate conversational context while retaining deterministic signals for obvious complaints and legal or cancellation risks.

## Architecture

### Persistent configuration

Introduce an Enterprise configuration record with one row per monitored inbox. The record belongs to an account and an inbox and stores:

- `enabled`
- `management_team_id`
- `complaint_label_id`
- `critical_label_id`

The database enforces one record per inbox. Model validation enforces that the inbox, team, and labels belong to the same account and that the inbox is WhatsApp for the first release.

A dedicated settings-backed account feature flag controls access to the monitor settings page. It is enabled only for account 4 during production setup. This avoids the exhausted 63-bit `feature_flags` column.

### Account settings page

Add **Settings -> Conversation monitor** for account administrators. The page contains:

- an enabled switch;
- a WhatsApp inbox selector;
- a management team selector;
- a complaint label selector;
- a critical-risk label selector;
- a visible explanation that the monitor is silent and never replies or reassigns conversations.

Saving uses an account-scoped singleton-style API for the selected inbox. The page shows validation errors inline and the current operational state. No installation JSON is exposed.

Team recipients remain manageable through the existing Teams page. Changing team membership changes who receives mention notifications without reconfiguring the monitor.

### Event and processing flow

1. The Enterprise async dispatcher receives `message_created`.
2. The monitor listener ignores private, outgoing, activity, and non-customer messages.
3. If the inbox has an enabled and valid monitor configuration, it schedules a debounced background job for the conversation.
4. The job discards stale executions so a burst of customer messages is evaluated once with current context.
5. A deterministic detector checks strong complaint and critical-risk signals first.
6. If deterministic signals are inconclusive, an LLM classifier evaluates recent public conversation context and returns `none`, `complaint`, or `critical`, a confidence value, and a short reason without personal data.
7. `none` produces no changes.
8. `complaint` applies the complaint label and creates one private note mentioning the management team.
9. `critical` applies both complaint and critical labels and creates a critical private note.
10. Repeated messages at the same risk level update nothing. A later upgrade from complaint to critical creates one additional alert.

The listener never waits for classification and therefore cannot delay Captain or a human response.

### Incident lifecycle and idempotency

Monitor state is stored as internal conversation metadata, separate from user-facing custom attributes. It records the current incident identifier, highest alerted severity, last evaluated message, and alert timestamps.

Resolving a conversation closes the current incident for monitoring purposes. A later incoming customer message starts a new incident and may alert again. Labels remain as historical markers unless a user removes them.

Private notes include monitor metadata so they are excluded from classification context and can be audited without parsing their text.

### Alerts

The monitor uses a private note with a Chatwoot team mention. This provides in-app mention notifications to current team members and keeps the reason visible to staff in the conversation timeline.

Complaint note example:

> @gestao A conversa apresenta sinais de reclamação e precisa de acompanhamento. Motivo: produto relatado como danificado.

Critical note example:

> @gestao Atenção crítica: a conversa apresenta risco de cancelamento, cobrança indevida ou medida jurídica. Motivo: cliente mencionou Procon.

The note must not instruct staff to change status or ownership automatically.

## Coexistence with Captain

The monitor is not attached through `AgentBotInbox`. Captain remains free to own the conversational inbox integration, answer using its knowledge and guidelines, or hand off to a person.

The monitor observes only incoming customer messages. It ignores Captain and human outgoing messages. Captain configuration and content remain entirely in Captain's existing interface.

Account 4 currently has Captain feature flags enabled but has no assistant configured or attached to inbox 62. Creating and configuring that assistant is a separate operational task and is not required for silent monitoring to work.

## Retirement of the intrusive triage

The deployment must retire the old behavior rather than leave two systems active:

- disable `WHATSAPP_TRIAGE_CONFIG`;
- detach `Triagem WhatsApp` from inbox 62 and remove the bot record if it has no remaining attachments;
- remove the menu, acknowledgement, routing, assignment, priority, SLA, escalation, and conversation-lock code paths;
- stop changing greeting and out-of-office messages during monitor setup;
- remove obsolete triage control metadata from conversations without changing human teams or assignees;
- open only conversations that remain pending solely because they were held by the old triage bot;
- retire the JSON runbook and replace it with monitor administration and rollback instructions;
- retain or rename the existing complaint labels where doing so preserves conversation history.

Production cleanup must first audit affected conversations and report counts. It must not bulk-clear legitimate human assignments or team ownership.

## Error handling

- If the LLM call fails, deterministic signals may still alert; otherwise the monitor performs no mutation and logs the failure.
- If the configured team, label, or inbox is missing or belongs to another account, the configuration is non-operational and no job is scheduled.
- Label application, private note creation, and incident-state update occur in one transaction.
- Concurrent jobs lock the conversation and re-check the highest alerted severity before writing.
- A stale debounced job exits without changes.
- No failure path may send a public message, route, assign, close, reopen, or reprioritize a conversation.

## Security and privacy

- API endpoints are account-scoped and administrator-only.
- Cross-account inbox, team, and label IDs are rejected.
- Alert reasons are limited in length and must not contain names, phone numbers, addresses, or message excerpts.
- LLM instrumentation follows existing Chatwoot Enterprise patterns and does not add conversation text to application logs.

## Verification

Repository verification:

- Ruby lint for changed backend files.
- JavaScript/Vue lint for changed frontend files.
- Rails boot and Zeitwerk checks.
- Frontend build or targeted component execution sufficient to prove the new route renders.
- A focused Rails runner scenario in a transaction proving complaint labeling, private mention creation, critical upgrade idempotency, and no changes to status, priority, team, assignee, or public-message count.

Production verification for account 4:

- The old Agent Bot is no longer attached to inbox 62 and does not appear as its active bot.
- The monitor configuration is enabled only for account 4 / inbox 62.
- A normal message produces no monitor output.
- A complaint adds the complaint label and one private management note.
- Repeating the complaint produces no duplicate note.
- Escalating the same incident to a critical signal adds the critical label and one critical note.
- No test changes status, priority, team, assignee, or sends a public message.
- App, worker, and real-time worker run the same immutable image and remain healthy.
- Other accounts and inboxes remain unaffected.

## Rollback

Disable the monitor record through the account settings page. Disabled or invalid configuration makes the listener a no-op; Captain and normal inbox behavior continue unchanged. Existing labels and private notes remain as audit history.

The old intrusive bot is not automatically reattached during rollback. Restoring that behavior would require an explicit deployment and is intentionally outside the operational rollback path.
