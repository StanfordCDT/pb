class CreateVoteApprovals < ActiveRecord::Migration
  def change
    create_table :vote_approvals do |t|
      t.references :voter, index: true, null: false
      t.references :project, index: true, null: false
      t.integer :cost

      t.timestamps null: false
    end
  end
end
