class File
    module FileExtensions
        def self.mkfifo(name, mode="666", open_mode="r")
            if File.exists? name and File.pipe? name # Leftover from before
                File.delete name
            end

            # apalling, but ruby/dl has x-p problems
            if ! File.exists? name
                `mkfifo -m #{ mode } #{ name }`
            end

            return File.open(name, open_mode)
        end
    end
    include FileExtensions
end
