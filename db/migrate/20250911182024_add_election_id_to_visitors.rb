# frozen_string_literal: true

class AddElectionIdToVisitors < ActiveRecord::Migration[7.0]
  def up
    add_column :visitors, :election_id, :integer, null: true
    add_index  :visitors, :election_id

    # Minimal AR classes scoped to this migration (avoid app models)
    election_class = Class.new(ActiveRecord::Base) { self.table_name = "elections" }
    visitor_class  = Class.new(ActiveRecord::Base) { self.table_name = "visitors"  }

    slug_to_id = election_class.pluck(:slug, :id).to_h
    base_urls = ['http://localhost:3000', 'https://pbstanford.org/']
    
    error_count = 0
    processed_count = 0

    visitor_class.find_in_batches(batch_size: 1000) do |batch|
      batch.each do |v|
        begin
          url   = v[:url].to_s
          base  = base_urls.find { |b| url.start_with?(b) }
          election_id = nil

          if base
            rest = url[base.length..] || ""
            # Remove query string before splitting to handle URLs like "/election_slug?locale=en"
            path_without_query = rest.split('?').first
            # Check if path_without_query is not nil before splitting
            if path_without_query
              # first non-empty segment after base
              first_segment = path_without_query.split("/", 2).first
              if first_segment && !first_segment.empty?
                election_id = slug_to_id[first_segment]
              end
            end
          else
            Rails.logger.warn "Migration URL parsing: URL doesn't match expected base patterns | URL: #{url}"
            error_count += 1
          end

          # Skip write if already correct (most rows start at nil via default)
          v.update_columns(election_id: election_id) if v[:election_id] != election_id
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
  