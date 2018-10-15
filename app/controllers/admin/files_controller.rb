module Admin
  class FilesController < ApplicationController
    before_action :set_no_cache
    before_action :require_admin_auth

    def index
      @election = Election.find(params[:election_id])
      @files = Dir.glob(File.join(@election.store_dir, '*')).sort.map do |path|
        {filename: File.basename(path), size: File.size(path), ctime: File.ctime(path)}
      end
    end

    def create
      election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(election)
      dir = election.store_dir
      total_file_size = Dir.glob(File.join(dir, '*')).map { |path| File.size(path) }.sum

      uploaded_io = params[:file]
      if uploaded_io.nil?
        redirect_to action: :index
        return
      end
      if uploaded_io.size + total_file_size > 20.megabytes
        flash[:errors] = ['The total file size must not exceed 20 megabytes.']
        redirect_to action: :index
        return
      end
      FileUtils::mkdir_p(dir)
      File.open(File.join(dir, uploaded_io.original_filename.strip), 'wb') do |file|
        file.write(uploaded_io.read)
      end

      flash[:notice] = uploaded_io.original_filename + ' was successfully uploaded.'
      redirect_to action: :index
    end

    def destroy
      election = Election.find(params[:election_id])
      raise "error" if !current_user.can_update_election?(election)
      filename = params[:id].strip.gsub(/\\|\//, '')
      raise "error" if filename == '.' || filename == '..'
      File.delete(File.join(election.store_dir, filename))
      redirect_to action: :index
    end
  end
end
