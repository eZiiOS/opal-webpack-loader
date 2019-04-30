module OpalWebpackLoader
  class LoadPathManager
    def self.get_load_path_entries(path)
      path_entries = []
      return [] unless Dir.exist?(path)
      dir_entries = Dir.entries(path)
      dir_entries.each do |entry|
        next if entry == '.'
        next if entry == '..'
        next unless entry
        absolute_path = File.join(path, entry)
        if File.directory?(absolute_path)
          more_path_entries = get_load_path_entries(absolute_path)
          path_entries.push(*more_path_entries) if more_path_entries.size > 0
        elsif (absolute_path.end_with?('.rb') || absolute_path.end_with?('.js')) && File.file?(absolute_path)
          path_entries.push(absolute_path)
        end
      end
      path_entries
    end

    def self.create_load_paths_cache
      load_paths = if File.exist?(File.join('bin', 'rails'))
                     %x{
                         bundle exec rails runner "puts (Rails.configuration.respond_to?(:assets) ? (Rails.configuration.assets.paths + Opal.paths).uniq : Opal.paths)"
                       }
                   else
                     %x{
                         bundle exec ruby -e 'if File.exist?("app_loader.rb"); require "./app_loader.rb"; else; require "bundler/setup"; Bundler.require; set :run, false if defined? Sinatra; end; puts Opal.paths'
                       }
                   end
      if $? == 0
        load_path_lines = load_paths.split("\n")
        load_path_lines.pop if load_path_lines.last == ''

        load_path_entries = []

        cwd = Dir.pwd

        load_path_lines.each do |path|
          next if path.start_with?(cwd)
          more_path_entries = get_load_path_entries(path)
          load_path_entries.push(*more_path_entries) if more_path_entries.size > 0
        end
        cache_obj = { 'opal_load_paths' => load_path_lines, 'opal_load_path_entries' => load_path_entries }
        Dir.mkdir(OpalWebpackLoader::CompileServer::OWL_CACHE_DIR) unless Dir.exist?(OpalWebpackLoader::CompileServer::OWL_CACHE_DIR)
        File.write(OpalWebpackLoader::CompileServer::OWL_LP_CACHE, Oj.dump(cache_obj, {}))
        load_path_lines
      else
        raise 'Error getting load paths!'
        exit(2)
      end
    end
  end
end
