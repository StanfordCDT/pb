# frozen_string_literal: true

class AddElectionIdToVisitors < ActiveRecord::Migration[7.0]
  def up
    add_column :visitors, :election_id, :integer, null: false, default: -1
    add_index  :visitors, :election_id

    # Minimal AR classes scoped to this migration (avoid app models)
    election_klass = Class.new(ActiveRecord::Base) { self.table_name = "elections" }
    visitor_klass  = Class.new(ActiveRecord::Base) { self.table_name = "visitors"  }

    slug_to_id = election_klass.pluck(:slug, :id).to_h
    bases = Rails.application.config.base_urls
    
    error_count = 0
    processed_count = 0

    visitor_klass.find_in_batches(batch_size: 1000) do |batch|
      batch.each do |v|
        begin
          url   = v[:url].to_s
          base  = bases.find { |b| url.start_with?(b) }
          eid   = -1

          if base
            rest = url[base.length..] || ""
            # Remove query string before splitting to handle URLs like "/election_slug?locale=en"
            path_without_query = rest.split('?').first
            # Check if path_without_query is not nil before splitting
            if path_without_query
              # first non-empty segment after base
              first_segment = path_without_query.split("/", 2).first
              if first_segment && !first_segment.empty?
                eid = slug_to_id[first_segment] || -1
              end
            end
          else
            Rails.logger.warn "Migration URL parsing: URL doesn't match expected base patterns | URL: #{url}"
            error_count += 1
          end

          # Skip write if already correct (most rows start at -1 via default)
          v.update_columns(election_id: eid) if v[:election_id] != eid
          processed_count += 1
          
        rescue => e
          Rails.logger.error "Migration URL parsing failed: #{e.message} | URL: #{url} | Created: #{v[:created_at]}"
          error_count += 1
        end
      end
    end
    
    Rails.logger.info "Migration completed: #{processed_count} visitors processed, #{error_count} errors"
  end
  
    def down
      remove_index  :visitors, column: :election_id
      remove_column :visitors, :election_id
    end
  end
  