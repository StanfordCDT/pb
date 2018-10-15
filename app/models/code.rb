class Code < ApplicationRecord
  enum status: [:ok, :test, :void, :personal_id]
  belongs_to :code_batch
end
