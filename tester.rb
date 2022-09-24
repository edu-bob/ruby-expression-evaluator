##
# Test driver for Expressions class
#
# Input:
#  Line oriented.  Lines are either
#     name="value"
#     expression
#

require 'expressions'

dict = Hash.new;

##
# doExpand - lambda passed to evaluator to expand macros in strings
#

doExpand = lambda do |str|
  result = str
  str.scan(/{[\w\d:]*}/).each do |macro|
    if dict[macro[1..-2]] then
      result.gsub!("#{macro}",dict[macro[1..-2]])
    end
  end
  result
end

extraOps = lambda do |op,args|
  case op
  when "rev"
    return args[0].to_s.reverse()
  end
end

##
# Read STDIN (or named files) file line by line
#
expected = nil
pass = 0
fail = 0
unchecked = 0
ARGF.each do |line|
  line.gsub!(/[\r\n]/, "")
  if line.length() == 0 then
    puts ""
    next
  end

  # Test for name=value
  if line =~ /(\w+)\s*=\s*(.*)/ then
    var = $1
    val = $2
    # Strip quotation marks, if any
    val.gsub!(/^"(.*)"\s*$/, '\1') if val =~ /^".*"\s*$/
    val.gsub!(/^'(.*)'\s*$/, '\1') if val =~ /^'.*'\s*$/
    dict[var] = val
    puts "Set #{var} = #{val}"
  elsif line =~ /^\s*=\s*(.*)/ then
    expected = $1
    puts line
  elsif line =~ /^\s*#/ then
    puts line
  else
    begin
      result = Expressions.evaluate(line, expander=doExpand, exops=extraOps,verbosity=0)
      if !expected.nil? then
        if result.to_s == expected.to_s then
          puts "#{line} => #{result} OK"
          pass += 1
        else
          puts "#{line} => #{result} INCORRECT"
          fail += 1
        end
      else
        puts "#{line} => #{result}"
        unchecked += 1
      end
    rescue StandardError => e  
      puts "ERROR: #{line} => #{e.message}"
#      puts e.backtrace
    end
    expected = nil
  end
end
puts "-----"
puts "#{pass} passed, #{fail} failed, #{unchecked} unchecked"
