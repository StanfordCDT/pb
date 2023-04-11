class VoteToken < ApplicationRecord
    belongs_to :voter
    belongs_to :project
    validate :validate_cost

    private

    def validate_cost
      if cost < 0
        errors.add(:cost)
      end
    end
  end
