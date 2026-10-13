class AddArchivedToInboxes < ActiveRecord::Migration[7.2]
  def change
    add_column :inboxes, :archived, :boolean, default: false, null: false
  end
end
