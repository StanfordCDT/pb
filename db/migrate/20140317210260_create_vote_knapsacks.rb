class CreateVoteKnapsacks < ActiveRecord::Migration[5.2]
  def change
    create_table :vote_knapsacks do |t|
      t.references :voter, index: true, null: false
      t.references :project, index: true, null: false
      t.integer :cost

      t.timestamps null: false
    end
  end
end
