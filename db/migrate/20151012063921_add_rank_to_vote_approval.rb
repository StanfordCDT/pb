class AddRankToVoteApproval < ActiveRecord::Migration
  def change
    add_column :vote_approvals, :rank, :integer, default: 1
  end
end
