module Admin
  class CodeBatchesController < ApplicationController
    before_action :set_no_cache
    before_action :require_admin_auth

    def index
      @election = Election.find(params[:election_id])
      @code_batches = @election.code_batches
    end

    def show
      @election = Election.find(params[:election_id])
      @code_batch = @election.code_batches.find(params[:id])
      id = params[:id]

      respond_to do |format|
        format.html do
          @codes = @code_batch.codes.joins("LEFT OUTER JOIN voters ON voters.election_id = " + @election.id.to_i.to_s + " AND voters.authentication_method = 'code' AND voters.authentication_id = codes.code").select('codes.*, COUNT(voters.id) AS used').group('codes.id').order(:code)
          #@codes = @code_batch.codes
        end
        format.pdf do
          codes = @code_batch.codes
          n = codes.length

          nr = 8  # Number of rows.
          nc = 3  # Number of columns.
          x0 = 0
          y0 = 0
          show_borders = false

          pdf = Prawn::Document.new(page_size: 'LETTER', margin: [0, 0, 0, 0]) do
            #font "Courier"
            font "Times-Roman"

            w = bounds.width / nc
            h = bounds.height / nr

            n.times do |i|
              if i % (nr*nc) == 0
                if i != 0
                  start_new_page
                end

                if show_borders
                  (0..nc).each { |j| line [x0 + j*w, y0], [x0 + j*w, y0 + nr*h] }
                  (0..nr).each { |j| line [x0, y0 + j*h], [x0 + nc*w, y0 + j*h] }
                  stroke
                end

                # if show_page_number
                #   move_up 16
                #   font_size 12
                #   text "Code Batch #" + id + "   Page " + (i / (nr*nc) + 1).to_s + "/" + (n.to_f / (nr*nc)).ceil.to_s
                # end
              end

              font_size 34
              j = i % (nr*nc)
              r = j / nc
              c = j % nc
              text_box codes[i].code, at: [x0 + c*w, y0 + (nr-r)*h], width: w, height: h, align: :center, valign: :center, character_spacing: 2.0
            end

          end
          send_data pdf.render, filename: id + '.pdf', type: 'application/pdf', disposition: 'inline'
        end
        format.txt do
          data = @code_batch.codes.map(&:code).join("\n") + "\n"
          send_data data, filename: "codes_#{id}.txt", type: 'text/plain'
        end
        format.csv do
          data = @code_batch.codes.map(&:code).join("\n") + "\n"
          send_data data, filename: "codes_#{id}.csv"
        end
      end
    end

    def new
      @election = Election.find(params[:election_id])
    end

    def import
      @election = Election.find(params[:election_id])
    end

    def create
      require 'set'
      @election = Election.find(params[:election_id])

      n_codes = params[:code_batch][:n_codes].to_i
      if n_codes < 1 || n_codes > 20000
        flash[:errors] = ['The number of codes must be in range 1 - 20000.']
        redirect_to action: :new
        return
      end

      format = params[:code_batch][:format]
      test_i = 0

      ActiveRecord::Base.transaction do
        codes = @election.codes.pluck(:code).to_set

        code_batch = CodeBatch.new
        code_batch.election = @election
        code_batch.user = current_user
        code_batch.save!

        # - filter offensive words
        # - some people confuse 'q' with g, 9 ... might be because of the font
        # - vertically ambiguous characters like 8, s, w, d, p, ...
        code_chars = (('a'..'z').to_a + ('0'..'9').to_a) - ['o', '0', '1', 'l', 'q']
        access_code_chars = ('1'..'9').to_a
        n_codes.times do
          c = nil
          loop do
            # In case of access codes, generate 10 digit codes prefixed by the given prefix
            if format == 'access_codes'
              c = (0...10).map { |_| access_code_chars.sample }.join
              c = params[:code_batch][:access_code_prefix].strip + c
            elsif format == 'test_codes'
              c = '_test' + test_i.to_s
              test_i += 1
            else
              c = (0...7).map { |_| code_chars.sample }.join
            end
            break if !codes.include?(c)
          end
          codes << c
          code = Code.new
          code.code = c
          code.code_batch = code_batch
          code.status = (format == 'test_codes') ? :test : :ok
          code.save!
        end
      end
      redirect_to action: :index
    end

    def post_import
      require 'set'
      @election = Election.find(params[:election_id])

      # Import codes from a .txt file
      import_file = params[:code_batch][:import_file] if !params[:code_batch].nil?
      if import_file.nil?
        redirect_to action: :import
        return
      end

      personal_id_codes = params[:code_batch][:personal_id].to_i != 0
      ActiveRecord::Base.transaction do
        code_batch = CodeBatch.new
        code_batch.election = @election
        code_batch.user = current_user
        code_batch.save!

        if true
          # Use a single mass insert for the highest performance.
          # TODO: Validation
          code_batch_id = code_batch.id.to_s
          status = Code.statuses[personal_id_codes ? :personal_id : :ok].to_s
          rows = import_file.read.split("\n").map do |c|
            c = sanitize_code(c)
            c.empty? ? nil : ("(" + ActiveRecord::Base.connection.quote(c) + "," + code_batch_id + "," + status + ",UTC_TIMESTAMP(),UTC_TIMESTAMP())")
          end
          sql_query = "INSERT INTO codes (`code`, `code_batch_id`, `status`, `created_at`, `updated_at`) VALUES " + rows.compact.join(",")
          ActiveRecord::Base.connection.execute(sql_query)
        else
          import_file.read.split("\n").each do |c|
            code = Code.new
            code.code = sanitize_code(c)
            code.code_batch = code_batch
            code.status = personal_id_codes ? :personal_id : :ok
            code.save!
          end
        end
      end
      redirect_to action: :index
    end

    def destroy
      election = Election.find(params[:election_id])
      code_batch = election.code_batches.find(params[:id])

      codes = code_batch.codes.pluck(:code)
      used_codes = code_batch.election.voters.where(authentication_method: 'code').pluck(:authentication_id)  # TODO: not very efficient?
      if !(codes & used_codes).empty?   # at least one code in the batch has been used
        if !current_user.superadmin?
          render html: "<html><body>At least one code in this batch has been used. Please contact the Stanford team to delete this code batch.</body></html>".html_safe
          return
        end

        # TODO: very dangerous
        Voter.destroy_all(election_id: code_batch.election.id, authentication_method: 'code', authentication_id: codes)
      end

      code_batch.destroy
      redirect_to action: :index
    end

    # This method is currently unused.
    def void  # TODO: move this to code controller
      election = Election.find(params[:election_id])
      code = election.codes.find(params[:code_id])
      code_batch = code.code_batch
      code.update_attribute(:status, 2)
      redirect_to action: :view, id: code_batch.id
    end

    private

    def sanitize_code(c)
      # Remove non-alphanumeric characters and strip leading zeros in the code.
      # NOTE: This is a bit different from sanitize_code in vote_controller.rb.
      c.split("&").map { |x|
        x.downcase.gsub(/[^0-9a-z_]/, '').sub(/^0+/, '')
      }.join("&")
    end
  end
end
