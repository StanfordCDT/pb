class Visitor < ApplicationRecord
  belongs_to :election, optional: true
end
