class CreateConversationResponseAttempts < ActiveRecord::Migration[7.2]
  def change
    create_attempts
    create_tracking_periods
  end

  private

  def create_attempts
    create_table :conversation_response_attempts do |t|
      t.bigint :account_id, :inbox_id, :conversation_id, :conversation_display_id, :assignee_id, :customer_message_id, null: false
      t.bigint :team_id, :responder_id, :reply_message_id
      t.string :store_code
      t.string :response_kind, null: false
      t.datetime :waiting_since, :started_at, :due_at, null: false
      t.integer :threshold_seconds, null: false
      t.boolean :business_hours, null: false, default: false
      t.string :outcome, null: false, default: 'pending'
      t.string :end_reason
      t.datetime :ended_at, :replied_at
      t.integer :response_seconds, :wait_seconds
      t.timestamps
    end
    add_index :conversation_response_attempts, [:account_id, :started_at], name: 'response_attempts_account_started'
    add_index :conversation_response_attempts, :conversation_id, unique: true, where: 'ended_at IS NULL', name: 'response_attempts_open'
  end

  # When deadline history was being collected per inbox, so reports can tell "no misses" from "not recorded".
  def create_tracking_periods
    create_table :response_tracking_periods do |t|
      t.bigint :account_id, :inbox_id, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.timestamps
    end
    add_index :response_tracking_periods, [:account_id, :inbox_id, :started_at], name: 'response_tracking_periods_lookup'
    add_index :response_tracking_periods, :inbox_id, unique: true, where: 'ended_at IS NULL', name: 'response_tracking_periods_open'
  end
end
