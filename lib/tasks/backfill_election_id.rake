# lib/tasks/backfill_election_id.rake
namespace :backfill do
  desc "Backfill visitors.election_id from visitor.url. Usage: BATCH_SIZE=1000 LOG_PATH=log/backfill.csv bundle exec rake backfill:election_id"
  task election_id: :environment do
    require "cgi"
    require "csv"

    batch_size = (ENV["BATCH_SIZE"] || 1000).to_i
    log_path   = ENV["LOG_PATH"]

    # Helper: normalize slugs consistently
    def normalize_slug(raw)
      return "" if raw.nil?
      s = raw.to_s
      # decode percent-encoding, replace non-breaking spaces, strip whitespace, downcase
      CGI.unescape(s).gsub("\u00A0", " ").strip.downcase
    end

    deprecated_raw = {
        "cambridge": 32,
        "chicago22": 12, 
        "vallejo2": 36,
        "seattled1": 38,
        "seattled4": 41,
        "seattled2": 39,
        "seattled5": 42,
        "seattled6": 43,
        "seattled7": 44,
        "seattled3": 40,
        "seattleD5": 42,
        "SeattleD5": 42,
        "dieppe2017": 46,
        "greensboro5pb2017": 60, 
        "2018merced2": 67, 
        "greensboro2018-1": 56,
        "Seattle": 81,
        "chicago2018_36": 52,
        "pb36vote2018b": 84,
        "savannah2018": 86,
        "durham2018": 89,
        "pb452018": 82,
        "vallejo": 69,
        "cambridge2017cambridge2017": 65,
        "chicago": 55,
        "ROCHESTER2019": 93,
        "Rochester2019": 93,
        "vallejo2019": 105,
        "49-2015": 9,
        "cambridge2019%20": 133,
        "beststartpb": 151,
        "NYC-WAGNER": 135,
        "atlanta-demo2020": 117,
        "demo-amherst": 154,
        "beststartLB2020": 151,
        "cambridge2021": 166,
        "chicago29_2021%C2%A0%C2%A0": 169,
        "adler-2021": 181,
        "atlanta-demo2021": 117,
        "beststartLB2022": 212,
        "2022-king-county-wa-east-Federal-way": 243,
        "2022-King-county-wa-skyway-capital": 206,
        "2022-health-ed-council-test": 213,
        "2022-health-ed-council-test2": 213,
        "2022-sarato-ga-ny": 247,
        "2022-Saratoga-ny": 247,
        "demo-2022-nyc22": 260,
        "demo-2022-nyc39-a": 257,
        "demo-2022-nyc39-b": 261,
        "2022-HEALTH-ED-COUNCIL": 213,
        "2022-nyc22-expense": 260,
        "2022-SF-tenderloin": 256,
        "2022-SF-Tenderloin": 256,
        "2023-oregon-metro-round1": 273,
        "demo-durham2023-d1": 276,
        "youthpowerpblb-2024": 263,
        "wilmington-2024": 296,
        "2024-SOFSA": 289,
        "youthpowerpblb-2024b": 263,
        "2024-king-county-Wa-white-center-capital": 244,
        "2024-King-County-wa-East-Renton": 241,
        "2024-KING-COUNTY-WA-WHITE-CENTER-TAX": 245,
        "2024-saratoga-ny%20": 323,
        "rvapb": 208,
        "youthpowerpblb2025": 295,
        "YPPB2025": 295,
        "2025-Albuquerque-D6": 329,
        "2025-SOFSA": 289,
        "berwyn-demo-25": 347
    }
    deprecated = deprecated_raw.transform_keys(&:to_s).transform_keys { |k| normalize_slug(k) }

    # Build normalized slug->id map from the elections table
    slug_to_id = Election.pluck(:slug, :id)
                      .map { |s, i| [normalize_slug(s), i] }
                      .to_h

    processed = 0
    errors = 0
    total = Visitor.where(election_id: nil).count
    Rails.logger.info "Backfill starting: #{total} visitors to process"

    csv = nil
    if log_path
      csv = CSV.open(log_path, "w")
      csv << ["visitor_id", "url", "error"]
    end

    Visitor.where(election_id: nil).find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |v|
        begin
          url = v.url.to_s
          uri = URI.parse(url) rescue nil
          path = uri ? (uri.path || "") : url.to_s

          # Candidate segments: first and second segments (handles /slug and /elections/slug)
          segments = path.sub(%r{\A/}, "").split("/", 3)
          candidates = [segments[0], segments[1]].compact.map { |seg| normalize_slug(seg) }.uniq

          election_id = nil
          candidates.each do |cand|
            next if cand.empty?
            election_id = slug_to_id[cand] || deprecated[cand]
            break if election_id
          end

          if election_id
            v.update_columns(election_id: election_id)
            processed += 1
          end
        rescue => e
          errors += 1
          msg = "Backfill error for visitor #{v.id}: #{e.class}: #{e.message}"
          Rails.logger.error(msg)
          csv << [v.id, v.url, e.message] if csv
        end
      end

      pct = total > 0 ? ((processed + errors).to_f / total * 100).round(1) : 0
      Rails.logger.info "Backfill progress: #{processed + errors}/#{total} (#{pct}%) — matched=#{processed}, errors=#{errors}"
    end

    csv.close if csv
    Rails.logger.info "Backfill finished: processed=#{processed}, errors=#{errors}"
  end
end