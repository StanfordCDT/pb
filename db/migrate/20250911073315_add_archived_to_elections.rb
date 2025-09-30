class AddArchivedToElections < ActiveRecord::Migration[5.2]
  def change
    add_column :elections, :archived, :json, null: true, default: nil
  end
end