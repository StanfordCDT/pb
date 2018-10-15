class VoteKnapsack < ApplicationRecord
  belongs_to :voter
  belongs_to :project
  validate :validate_cost

  private

  def validate_cost
    if (!project.adjustable_cost? && cost != project.cost) || (project.adjustable_cost? && (cost < project.cost_min || cost > project.cost || (cost - project.cost_min) % project.cost_step != 0))
      errors.add(:cost)
    end
  end
end
