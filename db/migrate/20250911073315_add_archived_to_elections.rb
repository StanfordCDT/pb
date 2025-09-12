class AddArchivedToElections < ActiveRecord::Migration[5.2]
    def change
      add_column :elections, :archived, :boolean, null: false, default: false
      add_index :elections, :archived
    end
  end