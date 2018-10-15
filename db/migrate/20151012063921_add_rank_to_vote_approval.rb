class AddRankToVoteApproval < ActiveRecord::Migration[5.2]
  def change
    add_column :vote_approvals, :rank, :integer, default: 1
  end
end
