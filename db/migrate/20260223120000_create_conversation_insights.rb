class CreateConversationInsights < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_insights do |t|
      t.bigint :conversation_id, null: false
      t.bigint :account_id, null: false
      t.decimal :estimated_value, precision: 10, scale: 2
      t.string :product_category
      t.string :customer_sentiment
      t.jsonb :key_topics, default: []
      t.integer :quality_score
      t.jsonb :quality_breakdown, default: {}
      t.jsonb :raw_llm_response, default: {}

      t.timestamps
    end

    add_index :conversation_insights, :conversation_id, unique: true
    add_index :conversation_insights, :account_id
    add_foreign_key :conversation_insights, :conversations
    add_foreign_key :conversation_insights, :accounts
  end
end
