class VotePlusminus < ApplicationRecord
  belongs_to :voter
  belongs_to :project
  validates :plusminus, inclusion: {in: [1, -1]}
end
