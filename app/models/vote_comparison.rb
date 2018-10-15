class VoteComparison < ApplicationRecord
  belongs_to :voter
  belongs_to :first_project, class_name: 'Project'
  belongs_to :second_project, class_name: 'Project'
  validate :validate_projects_and_costs
  validates :result, inclusion: {in: [-1, 0, 1]}

  private

  def validate_projects_and_costs
    election_id = voter.election_id
    if first_project.election_id != election_id || second_project.election_id != election_id || first_project.id == second_project.id || first_project.cost != first_project_cost || second_project.cost != second_project_cost
      errors.add(:base, 'projects or cost are invalid')
    end
  end
end
