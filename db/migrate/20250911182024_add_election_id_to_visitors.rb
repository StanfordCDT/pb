# frozen_string_literal: true

class AddElectionIdToVisitors < ActiveRecord::Migration[7.0]
    def up
      add_column :visitors, :election_id, :integer, null: false, default: -1
      add_index  :visitors, :election_id
  
      # Minimal AR classes scoped to this migration (avoid app models)
      election_klass = Class.new(ActiveRecord::Base) { self.table_name = "elections" }
      visitor_klass  = Class.new(ActiveRecord::Base) { self.table_name = "visitors"  }
  
      slug_to_id = election_klass.pluck(:slug, :id).to_h
      bases = ["http://localhost:3000/", "https://pbstanford.org/"]
  
      visitor_klass.find_in_batches(batch_size: 1000) do |batch|
        batch.each do |v|
          url   = v[:url].to_s
          base  = bases.find { |b| url.start_with?(b) }
          eid   = -1
  
          if base
            rest = url[base.length..] || ""
            # first non-empty segment after base
            first_segment = rest.split("/", 2).first
            if first_segment && !first_segment.empty?
              eid = slug_to_id[first_segment] || -1
            end
          end
  
          # Skip write if already correct (most rows start at -1 via default)
          v.update_columns(election_id: eid) if v[:election_id] != eid
        end
      end
    end
  
    def down
      remove_index  :visitors, column: :election_id
      remove_column :visitors, :election_id
    end
  end
  