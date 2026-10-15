# Agent response analytics: rollout and rollback

Durable history of each monitored five-business-minute response window (`conversation_response_attempts`), the spans in which it was collected (`response_tracking_periods`) and the report API `GET /api/v2/accounts/:account_id/agent_response_reports/{summary,details}` consumed by Hermes.

## What changes and what does not

- Both migrations are additive: two new tables and the nullable `inboxes.response_attempts_tracked_since`. There is no backfill, so the migrations themselves start no collection.
- Routing, response reassignment, assignment limits and capacity, manager notifications, message delivery, personal reads and inbox archiving behave as before. The reply path only adds writes to the history table inside the existing message transaction.
- New store classifications also keep `store_routing.origin_store`. A manual team transfer now pins the previous store there before rewriting `store`. The Hermes distribution ledger is not rewritten.

## Rollout

1. Deploy one image to app, worker and realtime worker and run the migrations once. Collection stays off on every inbox (`response_attempts_tracked_since` is `NULL`), so a rolling deploy cannot open windows that old code would later delete without closing.
2. Confirm all three services run the new image. Do not change any inbox's response-reassignment mode or auto-assignment while old and new processes coexist, because both changes now open or close collection.
3. Activate collection for each monitored inbox with a Rails runner. This sets the gate and opens a tracking period:

   ```ruby
   Inbox.find(INBOX_ID).update!(response_attempts_tracked_since: Time.current)
   ```

4. Coverage boundary: timers already armed before activation produce no history row. If such a window is automatically reassigned after activation, the replacement gets a normal window. The report shows the tracking period; earlier days appear as "no record", not as zero misses.
5. Verify in the report summary that `coverage.response_attempts.periods` lists the inbox, and that the first replies produce rows.

Turning a monitored inbox's mode off, or switching off its auto-assignment, closes the period and settles its open windows immediately. Turning it back on starts a new period. Recorded history is never deleted.

## Rollback

1. Stop collection before deploying the previous image. For each inbox, run `Inbox.find(INBOX_ID).update!(response_attempts_tracked_since: nil)`. This closes the tracking period and settles open windows as `settings_changed`. Without this step, old code would delete live timers without closing their history rows.
2. Deploy the previous image to all three services. The new tables and column can stay; old code ignores them. Drop them only with a reviewed down-migration after confirming the history is no longer needed.
3. Hermes keeps working without the API. Its dashboard shows an error state and the legacy distribution section keeps working.
