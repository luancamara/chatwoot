class CreateCaptainMessageRevisions < ActiveRecord::Migration[7.2]
  def change
    create_table :captain_message_revisions do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :request_id, null: false
      t.text :original_content, null: false
      t.text :revised_content
      t.text :selected_content
      t.string :outcome, null: false, default: 'pending'
      t.string :reason
      t.string :error_class
      t.string :model
      t.string :prompt_digest
      t.jsonb :usage, null: false, default: {}
      t.integer :duration_ms
      t.timestamps
    end

    add_index :captain_message_revisions, [:account_id, :conversation_id, :id], name: 'index_captain_revisions_on_conversation'
    add_index :captain_message_revisions, :created_at
  end
end
