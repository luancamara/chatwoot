class CreateMetaAdInsights < ActiveRecord::Migration[7.1]
  def change
    create_table :meta_ad_insights do |t|
      t.string :ad_id, null: false
      t.date :date, null: false
      t.decimal :spend, precision: 12, scale: 2, null: false, default: 0
      t.integer :impressions, null: false, default: 0
      t.integer :clicks, null: false, default: 0
      t.integer :reach, null: false, default: 0

      t.timestamps
    end

    add_index :meta_ad_insights, [:ad_id, :date], unique: true
    add_index :meta_ad_insights, :date
  end
end
