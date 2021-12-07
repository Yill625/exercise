require 'csv'
require 'octokit'
require 'optparse'

class DirectImporter
  DISPLAYED_ACTIVITIES = { 
    Hiking: '🥾',
    Running: '‍🏃‍♂️',
    Walking: '🚶‍♂️',
    Cycling: '🚴‍♂️',
    Basketball: '🏀'
  }

  def initialize(filepath, access_token, gist_id)
    @filepath = filepath
    @client = Octokit::Client.new(:access_token => access_token)
    @gist_id = gist_id
  end

  def activities
    @activities ||= CSV.parse(File.read(@filepath), headers: true)
  end

  def bar_chart(percent, size)
    syms = "░▏▎▍▌▋▊▉█"

    frac = ((size * 8 * percent) / 100).floor
    barsFull = (frac / 8).floor
    if (barsFull >= size)
      return [syms[8, 1] * size].join("")
    end
  
    semi = frac % 8
    return [syms[8, 1] * barsFull, syms[semi, 1]].join("").ljust(size, syms[0, 1])
  end

  def run
    totals = {}

    activities.each do |activity|
      if DISPLAYED_ACTIVITIES.keys.include?(activity["Name"].to_sym)
        totals[activity["Name"]] ||= 0
        totals[activity["Name"]] += activity["Distance"].to_f
      end
    end

    total = totals.values.sum
    body = totals.sort_by {|k, v| -v}.map do |key, value|
      "#{DISPLAYED_ACTIVITIES[key.to_sym]}"\
      "#{(value / 1000).ceil.to_s.rjust(6)}km"\
      " "\
      "#{bar_chart((value / total * 100).to_i, 20)}"
    end.join("\n")
    body << "\n#{(total / 1000).ceil.to_s.rjust(8)}km total"

    gist = @client.gist(@gist_id)
    filename = gist.files[gist[:files].to_h.keys.first]
    @client.edit_gist(@gist_id, files: { "#{filename[:filename]}": { content: body }})
  end
end

filename = nil
gist_id = nil
token = nil
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: ruby direct.rb [options] filename"
  opts.on("-t", "--token SECRET") { |arg| token = arg}
  opts.on("-g", "--gist GIST_ID") { |arg| gist_id = arg}
 
  begin
    # Parse and remove options from ARGV.
    filename = opts.parse!
  rescue OptionParser::ParseError => error
    # Without this rescue, Ruby would print the stack trace
    # of the error. Instead, we want to show the error message,
    # suggest -h or --help, and exit 1.
 
    $stderr.puts error
    $stderr.puts "(-h or --help will show valid options)"
    exit 1
  end
end

if filename && token && gist_id
  DirectImporter.new(filename.first, token, gist_id).run
end