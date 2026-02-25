class CreateScheduledMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :scheduled_messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.bigint :sender_id, null: false
      t.text :content, null: false
      t.datetime :scheduled_at, null: false
      t.integer :status, default: 0, null: false
      t.jsonb :content_attributes, default: {}
      t.timestamps
    end

    add_index :scheduled_messages, %i[scheduled_at status]
    add_index :scheduled_messages, %i[conversation_id status]
    add_foreign_key :scheduled_messages, :users, column: :sender_id
  end
end
