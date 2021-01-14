class ChangeColumnsInElections < ActiveRecord::Migration[5.2]
  def change
    add_column :elections, :real_election, :boolean, default: true, null: false
    add_column :elections, :remarks, :text

    change_column :elections, :allow_admins_to_update_election, :boolean, default: true
    change_column :elections, :allow_admins_to_see_voter_data, :boolean, default: true
    change_column :elections, :allow_admins_to_see_exact_results, :boolean, default: true
  end
end
