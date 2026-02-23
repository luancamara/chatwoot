class CreateFollowUpReminders < ActiveRecord::Migration[7.1]
  def change
    create_table :follow_up_reminders do |t|
      t.bigint :conversation_id, null: false
      t.bigint :account_id, null: false
      t.bigint :user_id, null: false
      t.datetime :remind_at, null: false
      t.integer :reminder_type, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.text :notes

      t.timestamps
    end

    add_index :follow_up_reminders, :conversation_id
    add_index :follow_up_reminders, :account_id
    add_index :follow_up_reminders, :user_id
    add_index :follow_up_reminders, [:remind_at, :status], name: 'index_follow_up_reminders_on_remind_at_and_status'
    add_foreign_key :follow_up_reminders, :conversations
    add_foreign_key :follow_up_reminders, :accounts
    add_foreign_key :follow_up_reminders, :users
  end
end
