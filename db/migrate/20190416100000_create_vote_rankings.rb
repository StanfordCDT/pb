class CreateVoteRankings < ActiveRecord::Migration[5.2]
  def change
    create_table :vote_rankings do |t|
      t.references :voter, index: true, null: false
      t.references :project, index: true, null: false
      t.integer :cost
      t.integer :rank

      t.timestamps null: false
    end
  end
end
