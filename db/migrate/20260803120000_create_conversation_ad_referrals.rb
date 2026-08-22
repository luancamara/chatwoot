class CreateConversationAdReferrals < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_ad_referrals do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true, index: { unique: true }
      t.references :inbox, null: false, foreign_key: true
      t.references :contact, foreign_key: true
      t.string :source_type
      t.string :source_id
      t.string :ad_id
      t.string :ctwa_clid
      t.string :source_url
      t.string :headline
      t.text :body
      t.jsonb :raw, null: false, default: {}
      t.datetime :referred_at, null: false

      t.timestamps
    end

    add_index :conversation_ad_referrals, [:account_id, :ad_id, :referred_at]
  end
end
