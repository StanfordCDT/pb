class Voter < ApplicationRecord
  belongs_to :election
  belongs_to :location, optional: true
  has_many :vote_approvals, dependent: :destroy
  has_many :vote_rankings, dependent: :destroy
  has_many :vote_comparisons, dependent: :destroy
  has_many :vote_knapsacks, dependent: :destroy
  has_many :vote_plusminuses, dependent: :destroy
  has_many :vote_tokens, dependent: :destroy
  has_one :voter_registration_record, dependent: :destroy
  serialize :data, JSON
  validates :authentication_id, presence: true, uniqueness: {scope: [:election_id, :authentication_method]}

  def origin  # used as the column name in the analytics
    #(authentication_method == 'code') ? location.name : ((authentication_method == 'phone') ? 'Phone' : nil)
    {authentication_method: authentication_method, location: location}
  end

  def test?
    authentication_method == 'code' && authentication_id == '_test'
  end

  def update_data(data)
    self.data = (self.data || {}).deep_merge(data)
    save
  end
end
