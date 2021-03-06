module CSVPP
  class Parser
    include Conversions

    attr_reader :format, :col_sep

    # @param input [String] path to input file
    # @param format [Format]
    # @param col_sep [String]
    #
    # @return [Array<Object>]
    def self.parse(input:,
                   format:,
                   col_sep: DEFAULT_COL_SEP,
                   convert_type: true,
                   &block)

      new(
        format: format,
        col_sep: col_sep,
        convert_type: convert_type,
      ).parse(input, &block)
    end

    # @param input [String] input string
    # @param format [Format]
    # @param col_sep [String]
    #
    # @return [Array<Object>]
    def self.parse_str(input:,
                   format:,
                   col_sep: DEFAULT_COL_SEP,
                   convert_type: true,
                   &block)

      new(
        format: format,
        col_sep: col_sep,
        convert_type: convert_type,
      ).parse_str(input, &block)
    end

    def initialize(format:, col_sep: DEFAULT_COL_SEP, convert_type: true)
      @format = format
      @col_sep = col_sep
      @convert_type = convert_type
    end

    def convert_type?
      !!@convert_type
    end

    def parse(path, &block)
      parse_io(File.open(path), &block)
    end

    def parse_str(str, &block)
      parse_io(str, &block)
    end

    def multiline?
      format.multiline?
    end

    private

    def set_value!(hash, var, value)
      hash[var] = value

      if convert_type?
        type = format.type(var)
        return if type.nil?

        hash[var] = convert(value,
                            to: type,
                            missings: format.missings(var),
                            true_values: format.true_values(var),
                            false_values: format.false_values(var))
      end
    end

    def add_result!(results, hash, &block)
      if block_given? && (obj = block.call(hash))
        results << obj
      else
        results << hash
      end
    end

    def parse_io(io, &block)
      return parse_multiline(io, &block) if multiline?

      results = []

      each_line_with_index(io) do |line, index|
        line_number = index + 1
        columns = line.split(col_sep, -1)

        hash = {}
        format.var_names.each do |var|
          hash["line_number"] = line_number

          index = format.index(var)
          value = columns[index].strip
          set_value!(hash, var, value)
        end

        add_result!(results, hash, &block)
      end

      results
    end

    def parse_multiline(io, &block)
      results = []
      hash = nil

      each_line_with_index(io) do |line, index|
        line_number = index + 1
        columns = line.split(col_sep, -1)
        line_id = columns[0]

        # If we reach a start of a group...
        if multiline_start?(line_id)
          # ...yield the previous group...
          add_result!(results, hash, &block) if hash

          # ...and start building a new one.
          hash = {}
          hash["line_number"] = line_number
        end

        next if hash.nil?

        format.vars_for_line(line_id).each do |var|
          index = format.index(var)
          value = columns[index].strip
          set_value!(hash, var, value)
        end
      end

      # Yield the last group.
      add_result!(results, hash, &block) if hash

      results
    end

    def multiline_start?(line_id)
      format.multiline_start?(line_id)
    end

    # Yield each line and corresponding index of io to given block, but skipping
    # the first lines according to the skip parameter defined in format.
    def each_line_with_index(io)
      offset = format.skip
      io.each_line.with_index do |line, index|
        yield(line, index) unless index < offset
      end
    end

  end
end
