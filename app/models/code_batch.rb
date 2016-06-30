class CodeBatch < ActiveRecord::Base
  belongs_to :election
  belongs_to :user
  has_many :codes, dependent: :delete_all
end
