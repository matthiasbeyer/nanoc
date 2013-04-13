# encoding: utf-8

module Nanoc::DataSources

  # The filesystem data source stores its items and layouts in nested
  # directories. Items and layouts are represented by one or two files; if it
  # is represented using one file, the metadata can be contained in this file.
  # The root directory for items is the `content` directory; for layouts, this
  # is the `layouts` directory.
  #
  # The metadata for items and layouts can be stored in a separate file with
  # the same base name but with the `.yaml` extension. If such a file is
  # found, metadata is read from that file. Alternatively, the content file
  # itself can start with a metadata section: it can be stored at the top of
  # the file, between `---` (three dashes) separators. For example:
  #
  #     ---
  #     title: "Moo!"
  #     ---
  #     h1. Hello!
  #
  # The metadata section can be omitted. If the file does not start with
  # three or five dashes, the entire file will be considered as content.
  #
  # The identifier of items and layouts is determined as follows. A file with
  # an `index.*` filename, such as `index.txt`, will have the filesystem path
  # with the `index.*` part stripped as a identifier. For example:
  #
  #     foo/bar/index.html → /foo/bar/
  #
  # In other cases, the identifier is calculated by stripping the extension.
  # If the `allow_periods_in_identifiers` attribute in the configuration is
  # true, only the last extension will be stripped if the file has multiple
  # extensions; if it is false or unset, all extensions will be stripped.
  # For example:
  #
  #     (`allow_periods_in_identifiers` set to true)
  #     foo.entry.html → /foo.entry/
  #     
  #     (`allow_periods_in_identifiers` set to false)
  #     foo.html.erb → /foo/
  #
  # Note that each item must have an unique identifier. nanoc will display an
  # error if two items with the same identifier are found.
  #
  # Some more examples:
  #
  #     content/index.html          → /
  #     content/foo.html            → /foo/
  #     content/foo/index.html      → /foo/
  #     content/foo/bar.html        → /foo/bar/
  #     content/foo/bar.baz.html    → /foo/bar/ OR /foo/bar.baz/
  #     content/foo/bar/index.html  → /foo/bar/
  #     content/foo.bar/index.html  → /foo.bar/
  #
  # The file extension does not determine the filters to run on items; the
  # Rules file is used to specify processing instructors for each item.
  #
  # It is possible to set an explicit encoding that should be used when reading
  # files. In the data source configuration, set `encoding` to an encoding
  # understood by Ruby’s `Encoding`. If no encoding is set in the configuration,
  # UTF-8 will be used.
  class Filesystem < Nanoc::DataSource

    identifier :filesystem

    # See {Nanoc::DataSource#up}.
    def up
    end

    # See {Nanoc::DataSource#down}.
    def down
    end

    # See {Nanoc::DataSource#setup}.
    def setup
      # Create directories
      %w( content layouts ).each do |dir|
        FileUtils.mkdir_p(dir)
      end
    end

    # See {Nanoc::DataSource#items}.
    def items
      load_objects('content', 'item', Nanoc::Item)
    end

    # See {Nanoc::DataSource#layouts}.
    def layouts
      load_objects('layouts', 'layout', Nanoc::Layout)
    end

    # See {Nanoc::DataSource#create_item}.
    def create_item(content, attributes, identifier, params={})
      create_object('content', content, attributes, identifier, params)
    end

    # See {Nanoc::DataSource#create_layout}.
    def create_layout(content, attributes, identifier, params={})
      create_object('layouts', content, attributes, identifier, params)
    end

  protected

    # Creates a new object (item or layout) on disk in dir_name according to
    # the given identifier. The file will have its attributes taken from the
    # attributes hash argument and its content from the content argument.
    def create_object(dir_name, content, attributes, identifier, params={})
      # Check for periods
      if (@config.nil? || !@config[:allow_periods_in_identifiers]) && identifier.include?('.')
        raise RuntimeError,
          "Attempted to create an object in #{dir_name} with identifier #{identifier} containing a period, but allow_periods_in_identifiers is not enabled in the site configuration. (Enabling allow_periods_in_identifiers may cause the site to break, though.)"
      end

      # Determine path
      ext = params[:extension] || '.html'
      path = dir_name + (identifier == '/' ? '/index.html' : identifier[0..-2] + ext)
      parent_path = File.dirname(path)

      # Notify
      Nanoc::NotificationCenter.post(:file_created, path)

      # Write item
      FileUtils.mkdir_p(parent_path)
      File.open(path, 'w') do |io|
        meta = attributes.stringify_keys_recursively
        unless meta == {}
          io.write(YAML.dump(meta).strip + "\n")
          io.write("---\n\n")
        end
        io.write(content)
      end
    end

    # Creates instances of klass corresponding to the files in dir_name. The
    # kind attribute indicates the kind of object that is being loaded and is
    # used solely for debugging purposes.
    #
    # This particular implementation loads objects from a filesystem-based
    # data source where content and attributes can be spread over two separate
    # files. The content and meta-file are optional (but at least one of them
    # needs to be present, obviously) and the content file can start with a
    # metadata section.
    #
    # @see Nanoc::DataSources::Filesystem#load_objects
    def load_objects(dir_name, kind, klass)
      all_split_files_in(dir_name).map do |base_filename, (meta_ext, content_ext)|
        # Get filenames
        meta_filename    = filename_for(base_filename, meta_ext)
        content_filename = filename_for(base_filename, content_ext)

        # Read content and metadata
        is_binary = !!(content_filename && !@site.config[:text_extensions].include?(File.extname(content_filename)[1..-1]))
        if is_binary && klass == Nanoc::Item
          meta                = (meta_filename && YAML.load_file(meta_filename)) || {}
          content_or_filename = content_filename
        else
          meta, content_or_filename = parse(content_filename, meta_filename, kind)
        end

        # Get attributes
        attributes = {
          :filename         => content_filename,
          :content_filename => content_filename,
          :meta_filename    => meta_filename,
          :extension        => content_filename ? ext_of(content_filename)[1..-1] : nil
        }.merge(meta)

        # Get identifier
        if meta_filename
          identifier = identifier_for_filename(meta_filename[(dir_name.length+1)..-1])
        elsif content_filename
          identifier = identifier_for_filename(content_filename[(dir_name.length+1)..-1])
        else
          raise RuntimeError, "meta_filename and content_filename are both nil"
        end

        # Get modification times
        meta_mtime    = meta_filename    ? File.stat(meta_filename).mtime    : nil
        content_mtime = content_filename ? File.stat(content_filename).mtime : nil
        if meta_mtime && content_mtime
          mtime = meta_mtime > content_mtime ? meta_mtime : content_mtime
        elsif meta_mtime
          mtime = meta_mtime
        elsif content_mtime
          mtime = content_mtime
        else
          raise RuntimeError, "meta_mtime and content_mtime are both nil"
        end

        # Create layout object
        klass.new(
          content_or_filename, attributes, identifier,
          :binary => is_binary, :mtime => mtime
        )
      end
    end

    # Finds all items/layouts/... in the given base directory. Returns a hash
    # in which the keys are the file's dirname + basenames, and the values a
    # pair consisting of the metafile extension and the content file
    # extension. The meta file extension or the content file extension can be
    # nil, but not both. Backup files are ignored. For example:
    #
    #   {
    #     'content/foo' => [ 'yaml', 'html' ],
    #     'content/bar' => [ 'yaml', nil    ],
    #     'content/qux' => [ nil,    'html' ]
    #   }
    def all_split_files_in(dir_name)
      # Get all good file names
      filenames = self.all_files_in(dir_name)
      filenames.reject! { |fn| fn =~ /(~|\.orig|\.rej|\.bak)$/ }

      # Group by identifier
      grouped_filenames = filenames.group_by { |fn| basename_of(fn) }

      # Convert values into metafile/content file extension tuple
      grouped_filenames.each_pair do |key, filenames|
        # Divide
        meta_filenames    = filenames.select { |fn| ext_of(fn) == '.yaml' }
        content_filenames = filenames.select { |fn| ext_of(fn) != '.yaml' }

        # Check number of files per type
        if ![ 0, 1 ].include?(meta_filenames.size)
          raise RuntimeError, "Found #{meta_filenames.size} meta files for #{key}; expected 0 or 1"
        end
        if ![ 0, 1 ].include?(content_filenames.size)
          raise RuntimeError, "Found #{content_filenames.size} content files for #{key}; expected 0 or 1"
        end

        # Reorder elements and convert to extnames
        filenames[0] = meta_filenames[0]    ? 'yaml'                                   : nil
        filenames[1] = content_filenames[0] ? ext_of(content_filenames[0])[1..-1] || '': nil
      end

      # Done
      grouped_filenames
    end

    # Returns all files in the given directory and directories below it.
    def all_files_in(dir_name)
      Nanoc::Extra::FilesystemTools.all_files_in(dir_name)
    end

    # Returns the filename for the given base filename and the extension.
    #
    # If the extension is nil, this function should return nil as well.
    #
    # A simple implementation would simply concatenate the base filename, a
    # period and an extension (which is what the
    # {Nanoc::DataSources::FilesystemCompact} data source does), but other
    # data sources may prefer to implement this differently (for example,
    # {Nanoc::DataSources::FilesystemVerbose} doubles the last part of the
    # basename before concatenating it with a period and the extension).
    def filename_for(base_filename, ext)
      if ext.nil?
        nil
      elsif ext.empty?
        base_filename
      else
        base_filename + '.' + ext
      end
    end

    # Returns the identifier that corresponds with the given filename, which
    # can be the content filename or the meta filename.
    def identifier_for_filename(filename)
      if filename =~ /(^|\/)index\.[^\/]+$/
        regex = ((@config && @config[:allow_periods_in_identifiers]) ? /\/?index\.[^\/\.]+$/ : /\/?index\.[^\/]+$/)
      else
        regex = ((@config && @config[:allow_periods_in_identifiers]) ? /\.[^\/\.]+$/         : /\.[^\/]+$/)
      end
      filename.sub(regex, '').cleaned_identifier
    end

    # Returns the base name of filename, i.e. filename with the first or all
    # extensions stripped off. By default, all extensions are stripped off,
    # but when allow_periods_in_identifiers is set to true in the site
    # configuration, only the last extension will be stripped .
    def basename_of(filename)
      filename.sub(extension_regex, '')
    end

    # Returns the extension(s) of filename. Supports multiple extensions.
    # Includes the leading period.
    def ext_of(filename)
      filename =~ extension_regex ? $1 : ''
    end

    # Returns a regex that is used for determining the extension of a file
    # name. The first match group will be the entire extension, including the
    # leading period.
    def extension_regex
      if @config && @config[:allow_periods_in_identifiers]
        /(\.[^\/\.]+$)/
      else
        /(\.[^\/]+$)/
      end
    end

    # Parses the file named `filename` and returns an array with its first
    # element a hash with the file's metadata, and with its second element the
    # file content itself.
    def parse(content_filename, meta_filename, kind)
      # Read content and metadata from separate files
      if meta_filename
        content = content_filename ? read(content_filename) : ''
        meta_raw = read(meta_filename)
        begin
          meta = YAML.load(meta_raw) || {}
        rescue Exception => e
          raise "Could not parse YAML for #{meta_filename}: #{e.message}"
        end
        return [ meta, content ]
      end

      # Read data
      data = read(content_filename)

      # Check presence of metadata section
      if data !~ /\A-{3,5}\s*$/
        return [ {}, data ]
      end

      # Split data
      pieces = data.split(/^(-{5}|-{3})\s*$/)
      if pieces.size < 4
        raise RuntimeError.new(
          "The file '#{content_filename}' appears to start with a metadata section (three or five dashes at the top) but it does not seem to be in the correct format."
        )
      end

      # Parse
      begin
        meta = YAML.load(pieces[2]) || {}
      rescue Exception => e
        raise "Could not parse YAML for #{content_filename}: #{e.message}"
      end
      content = pieces[4..-1].join.strip

      # Done
      [ meta, content ]
    end

    # Reads the content of the file with the given name and returns a string
    # in UTF-8 encoding. The original encoding of the string is derived from
    # the default external encoding, but this can be overridden by the
    # “encoding” configuration attribute in the data source configuration.
    def read(filename)
      # Read
      begin
        data = File.binread(filename)
      rescue => e
        raise RuntimeError.new("Could not read #{filename}: #{e.inspect}")
      end

      # Re-encode
      encoding = (@config && @config[:encoding]) || 'utf-8'
      data.force_encoding(encoding)
      data.encode!('utf-8')

      # Remove UTF-8 BOM
      data.gsub!("\xEF\xBB\xBF", '')

      data
    end

    # Raises an invalid encoding error for the given filename and encoding.
    def raise_encoding_error(filename, encoding)
      raise RuntimeError.new("Could not read #{filename} because the file is not valid #{encoding}.")
    end

  end

end
