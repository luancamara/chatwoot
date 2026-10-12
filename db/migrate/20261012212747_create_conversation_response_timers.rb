class CreateConversationResponseTimers < ActiveRecord::Migration[7.2]
  def change
    create_table :conversation_response_timers do |t|
      t.references :conversation, null: false, index: { unique: true }
      t.references :inbox, null: false
      t.datetime :waiting_since, null: false
      t.bigint :customer_message_id, null: false
      t.string :response_kind, null: false
      t.bigint :assignee_id
      t.datetime :due_at
      t.bigint :attempted_agent_ids, array: true, default: [], null: false
      t.bigint :notified_assignee_id
      t.timestamps
    end
    add_index :conversation_response_timers, :due_at, where: 'due_at IS NOT NULL', name: 'response_timers_due'
  end
end
