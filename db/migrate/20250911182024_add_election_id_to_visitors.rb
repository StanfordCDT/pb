# frozen_string_literal: true

class AddElectionIdToVisitors < ActiveRecord::Migration[7.0]
  def change
    add_column :visitors, :election_id, :integer, null: true
    add_index  :visitors, :election_id
  end
  def down
    remove_index  :visitors, column: :election_id
    remove_column :visitors, :election_id
  end
end
# class AddElectionIdToVisitors < ActiveRecord::Migration[7.0]
#   def up
#     add_column :visitors, :election_id, :integer, null: true
#     add_index  :visitors, :election_id

#     # Dictionary of election slugs to election IDs (add your mappings here)
#     deprecated_election_slug_to_id_dict = {
#         "cambridge": 32,
#         "chicago22": 12, 
#         "vallejo2": 36,
#         "seattled1": 38,
#         "seattled4": 41,
#         "seattled2": 39,
#         "seattled5": 42,
#         "seattled6": 43,
#         "seattled7": 44,
#         "seattled3": 40,
#         "seattleD5": 42,
#         "SeattleD5": 42,
#         "dieppe2017": 46,
#         "greensboro5pb2017": 60, 
#         "2018merced2": 67, 
#         "greensboro2018-1": 56,
#         "Seattle": 81,
#         "chicago2018_36": 52,
#         "pb36vote2018b": 84,
#         "savannah2018": 86,
#         "durham2018": 89,
#         "pb452018": 82,
#         "vallejo": 69,
#         "cambridge2017cambridge2017": 65,
#         "chicago": 55,
#         "ROCHESTER2019": 93,
#         "Rochester2019": 93,
#         "vallejo2019": 105,
#         "49-2015": 9,
#         "cambridge2019%20": 133,
#         "beststartpb": 151,
#         "NYC-WAGNER": 135,
#         "atlanta-demo2020": 117,
#         "demo-amherst": 154,
#         "beststartLB2020": 151,
#         "cambridge2021": 166,
#         "chicago29_2021%C2%A0%C2%A0": 169,
#         "adler-2021": 181,
#         "atlanta-demo2021": 117,
#         "beststartLB2022": 212,
#         "2022-king-county-wa-east-Federal-way": 243,
#         "2022-King-county-wa-skyway-capital": 206,
#         "2022-health-ed-council-test": 213,
#         "2022-health-ed-council-test2": 213,
#         "2022-sarato-ga-ny": 247,
#         "2022-Saratoga-ny": 247,
#         "demo-2022-nyc22": 260,
#         "demo-2022-nyc39-a": 257,
#         "demo-2022-nyc39-b": 261,
#         "2022-HEALTH-ED-COUNCIL": 213,
#         "2022-nyc22-expense": 260,
#         "2022-SF-tenderloin": 256,
#         "2022-SF-Tenderloin": 256,
#         "2023-oregon-metro-round1": 273,
#         "demo-durham2023-d1": 276,
#         "youthpowerpblb-2024": 263,
#         "wilmington-2024": 296,
#         "2024-SOFSA": 289,
#         "youthpowerpblb-2024b": 263,
#         "2024-king-county-Wa-white-center-capital": 244,
#         "2024-King-County-wa-East-Renton": 241,
#         "2024-KING-COUNTY-WA-WHITE-CENTER-TAX": 245,
#         "2024-saratoga-ny%20": 323,
#         "rvapb": 208,
#         "youthpowerpblb2025": 295,
#         "YPPB2025": 295,
#         "2025-Albuquerque-D6": 329,
#         "2025-SOFSA": 289,
#         "berwyn-demo-25": 347
#       }

#     # Minimal AR classes scoped to this migration (avoid app models)
#     election_class = Class.new(ActiveRecord::Base) { self.table_name = "elections" }
#     visitor_class  = Class.new(ActiveRecord::Base) { self.table_name = "visitors"  }

#     slug_to_id = election_class.pluck(:slug, :id).to_h
#     base_urls = ['http://localhost:3000', 'https://pbstanford.org/']
    
#     error_count = 0
#     processed_count = 0

#     visitor_class.find_in_batches(batch_size: 1000) do |batch|
#       batch.each do |v|
#         begin
#           url   = v[:url].to_s
#           base  = base_urls.find { |b| url.start_with?(b) }
#           election_id = nil

#           if base
#             rest = url[base.length..] || ""
#             # Remove query string before splitting to handle URLs like "/election_slug?locale=en"
#             path_without_query = rest.split('?').first
#             # Check if path_without_query is not nil before splitting
#             if path_without_query
#               # first non-empty segment after base
#               first_segment = path_without_query.split("/", 2).first
#               if first_segment && !first_segment.empty?
#                 # Check database first, then fall back to dictionary lookup
#                 election_id = slug_to_id[first_segment] || deprecated_election_slug_to_id_dict[first_segment]
#               end
#             end
#           else
#             Rails.logger.warn "Migration URL parsing: URL doesn't match expected base patterns | URL: #{url}"
#             error_count += 1
#           end

#           # Skip write if already correct (most rows start at nil via default)
#           v.update_columns(election_id: election_id) if v[:election_id] != election_id
#           processed_count += 1
          
#         rescue => e
#           Rails.logger.error "Migration URL parsing failed: #{e.message} | URL: #{url} | Created: #{v[:created_at]}"
#           error_count += 1
#         end
#       end
#     end
    
#     Rails.logger.info "Migration completed: #{processed_count} visitors processed, #{error_count} errors"
#   end

#   def down
#     remove_index  :visitors, column: :election_id
#     remove_column :visitors, :election_id
#   end
# end
  