class ElectionUser < ApplicationRecord
  enum status: [:admin, :volunteer]
  belongs_to :election
  belongs_to :user
  validates :user_id, uniqueness: {scope: :election_id}
  validates :status, presence: true
end
