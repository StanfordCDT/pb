class CreateVoteKnapsacks < ActiveRecord::Migration
  def change
    create_table :vote_knapsacks do |t|
      t.references :voter, null: false
      t.references :project, index: true, null: false
      t.integer :cost

      t.timestamps null: false
    end
  end
end
