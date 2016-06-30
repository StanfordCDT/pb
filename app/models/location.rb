class Location < ActiveRecord::Base
  belongs_to :election
  has_many :voters
  validates :name, presence: true, uniqueness: {scope: :election_id}
end
