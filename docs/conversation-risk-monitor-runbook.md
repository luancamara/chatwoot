# Conversation risk monitor

The conversation risk monitor watches incoming customer messages without taking over the conversation. It never sends public messages, changes status or priority, or changes the team or assignee.

## Routine configuration

Administrators configure it at **Settings → Conversation monitor**. Select:

- the WhatsApp inbox;
- the management team mentioned in private alerts;
- the complaint label;
- the critical-risk label;
- whether silent monitoring is enabled.

No Super Admin JSON configuration is used.

## Alert behavior

A complaint applies the complaint label and creates one private note mentioning the management team. A critical risk applies both labels and creates a critical private note. Repeated messages at the same severity do not create duplicate alerts. A complaint that becomes critical creates one additional alert.

Resolving the conversation closes the current incident. A later complaint can create a new incident and alert.

Deterministic risk phrases are evaluated first. The configured Captain/OpenAI credentials provide contextual classification when no deterministic phrase matches. If AI classification fails, the monitor remains silent and deterministic detection continues to work.

## Operational commands

```bash
bundle exec rails conversation_risk_monitor:status[62]
bundle exec rails conversation_risk_monitor:disable[62]
bundle exec rails conversation_risk_monitor:enable[62]
```

The legacy migration is a one-time deployment action:

```bash
bundle exec rails conversation_risk_monitor:migrate_legacy
```

It audits the old flow, disables its installation config, removes its internal conversation attributes, detaches the `Triagem WhatsApp` bot, and creates a disabled silent-monitor configuration. It does not change human teams or assignees. A pending conversation is opened only when it is still assigned to the legacy bot.

## Rollback

Disable the monitor from the settings page or run the disable task. The listener then becomes a no-op. Existing labels and private notes remain as audit history, and normal inbox/Captain behavior is unchanged.
