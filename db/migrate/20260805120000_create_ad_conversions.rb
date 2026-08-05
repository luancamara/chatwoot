class CreateAdConversions < ActiveRecord::Migration[7.1]
  def change
    create_table :ad_conversions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation_ad_referral, null: false, foreign_key: true, index: { name: 'index_ad_conversions_on_referral' }
      t.integer :erp_client_id
      t.string :erp_order_ref, null: false
      t.decimal :value, precision: 12, scale: 2, null: false, default: 0
      t.datetime :ordered_at, null: false
      t.string :status, null: false
      t.integer :erp_midia

      t.timestamps
    end

    add_index :ad_conversions, [:conversation_ad_referral_id, :erp_order_ref], unique: true, name: 'index_ad_conversions_on_referral_and_order'
    add_index :ad_conversions, [:account_id, :ordered_at]
    add_column :conversation_ad_referrals, :reconciled_at, :datetime
  end
end
