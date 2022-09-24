##
# This class parses and interprets simple prefix algebraic expressions
#
# Author: Robert L. Brown (rlb408, edu-bob)

class Expressions
  require "time"
  require "json"
  
  ##
  # @@params maps operators to the number of arguments they require.
  #
  # If an operator can take a variable number of arguments, say zero arguments  This list
  # is also used to display the list of known functions
  #
  # This raises a RunTimeError exception on syntax errors
  #
  # TODO: This needs to be passed in, or better, be augmented by caller input.
  #
  
  @@params = {
    'mod' => 2,
    'sub' => 2,
    'div' => 2,
    'add' => nil,
    'mult' => nil,
    'date_add' => [2,3],
    'date_sub' => [2,3],
    'to_csv' => nil,
    'concat' => nil,
    'exp' => 2,
    'abs' => 1,
    'gsub' => 3,
    'upcase' => 1,
    'downcase' => 1,
    'length' => 1,
    'strip' => 1,
    'match' => 2,
    'lt' => 2,
    'le' => 2,
    'gt' => 2,
    'ge' => 2,
    'eq' => 2,
    'ne' => 2,
    'if' => 3,
    'and' => nil,
    'or' => nil,
    "json_lookup" => [2,3],
    'is_empty' => 2,
  }

  OP = "op"
  STR = "str"
  VAL = "val"
  UNEG = "neg"
  LP = "("
  RP = ")"
  SUBTREE = "["
  
  ##
  # evaluate - Evaluate a string as a prefix expression and interpret it
  #
  # ==== Attributes
  #
  # * +str+ - a string containint the expression
  # * +expander - a lambda that can process strings for, say, macro expansion
  # * +exops - a lambda that can handle otherwise unknown functions
  # * +verbosity+ - a small integer denoting how much debugging to print
  #
  # ==== Examples
  #
  #  Expressions.evaluate('add(3,mult(4,5),add(4,5,6,7))' returns 45 (3 + (4*5) + (4+5+6+7))
  #  at verbosity=2, this also displays the postfix notation: ) ) 7 6 5 4 add ) 5 4 mult 3 add
  #

  def self.evaluate(str, expander=nil, exops=nil, verbosity=0)

    # Lexical analysis & tree building
    opstack = []
    vstack = []

    # Break up the input into tokens and build a tree structure of the expression

    str.scan(/-(?=[[:alpha:]])|\w+\(|".*?"|'.*?'|-?\d+(?:\.\d*)?|\)/).each do |tok|
      t = lambda {
        if tok[-1]=='(' then
          {type: OP, value: tok[0..-2]}
        elsif tok=="-"
          {type: UNEG, value: UNEG}
        elsif ['"', "'"].include? tok[0]
          {type: STR, value: tok[1..-2]}
        elsif tok[0]==')'
          {type: RP, value: RP}
        else
          {type: VAL, value: tok}
        end
      }.call

      puts "-----------","Processing #{t[:type]}=#{t[:value]}"  if verbosity >= 3
      
      case t[:type]
      when STR, VAL
        vstack.push(t)
      when OP
        opstack.push(t)
        vstack.push({type: LP})
      when RP
        index = vstack.reverse.index { |i| i[:type]==LP }
        tmp = [*vstack.pop(index),opstack.pop()];
        vstack.pop();
        vstack.push({type: SUBTREE, value: tmp})
        if opstack.last && opstack.last[:type]==UNEG then
          vstack.push(opstack.pop())
        end
      when UNEG
        opstack.push(t)
      end
      print "opstack: ", opstack.map { |t| t[:value] }.join(' '), "\n" if verbosity >= 3
    end

    # operator stack should be empty, otherwise there's a syntax error
    raise "Syntax error" if opstack.length() > 0 

    # walk the parse tree and generate postfix notation
    postfix = gen_postfix(vstack)

    puts(postfix, "--------") if verbosity >= 2
    
    # Interpreter - compute the value of the postfix expression

    istack = []
    postfix.each do |t|
      puts "-----------","Processing #{t[:type]}=#{t[:value]}" if verbosity >= 3
      case t[:type]
      when VAL, LP
        istack.push(t)
      when STR
        # for strings, run through the user-supplier expander, if any
        istack.push({type: VAL,value: (expander ? expander.call(t[:value]) : t[:value])})
      when OP
        # look for the beginning of the parameters list for this OP
        index = istack.reverse.index { |i| i[:type]==LP }
        argc = @@params[t[:value]]
        need = (argc.nil? ? nil : (argc.kind_of?(Array) ? argc : [argc,argc]))
        if need && (index<need[0] || index>need[1]) then
          raise "Function #{t[:value]} wants #{need[0]} " +
                (need[0]==need[1]? (need[0]==1 ? "arg" : "args") : "to #{need[1]} args") +
                ", got #{index}"
        end
        # grab the parameters, lose the left paren, evaluate the op, push the result onto the stack
        args = istack.pop(index)
        istack.pop
        istack.push({type: VAL,value: operator(t[:value], args.map{|t|t[:value]}, exops)})
      when UNEG
        # unary negative is a simple OP
        top = istack.pop()
        istack.push({type: top[:type],value: -top[:value]})
      end
    end
    # at the end of the postfix, the stack should have just the final result on it
    if istack.length > 1 then
      raise "Syntax error, too many results: " + istack.map {|t| t[:value]}.join(",")
    end
    istack.pop()[:value]
  end

  ##
  # return an array of known function names
  #

  def self.functions
    return @@params.keys.sort
  end

  private

  ##
  # Generate postfix for a tree-structured expression
  #

  def self.gen_postfix(tree)
    postfix = []
    tree.each do |t|
      case t[:type]
      when VAL, OP, STR, UNEG
        postfix.push(t)
      when SUBTREE
        postfix.push({type: LP, value: LP}, *gen_postfix(t[:value]))
      end
    end
    postfix
  end

  ##
  # Type-accommodating comparison function
  #
  def self.cmp(a,b)
    (a.to_s.match(/^-?(\d*\.)?\d+$/) && b.to_s.match(/^-?(\d*\.)?\d+$/) ) ?
      ( (a.to_s.match(/\./) || b.to_s.match(/\./)) ?
          (yield(a.to_f,b.to_f) ? 1 : 0) : (yield(a.to_i, b.to_i) ? 1 : 0)
      ) :
      yield(a, b) ? 1 : 0
  end

  ##
  # Evaluate a builtin operator
  #

  def self.operator(op,args,exops=nil)
#    puts args.map{|a| "#{a.class.name}=#{a}" }.join("\n")
    case op
    when "mult"
      return args.map{|v| v.to_f}.inject(1, :*)
    when "add"
      return args.map{|v| v.to_f}.inject(0, :+)
    when "mod"
      return args[0].to_f % args[1].to_f
    when "sub"
      return args[0].to_f - args[1].to_f
    when "div"
      return args[0].to_f / args[1].to_f
    when "date_add"
      t = Time.parse(args[0]) + args[1].to_i
      return t.strftime (args.length>2 ? args[2] : "%Y-%m-%d %H:%M %Z")
    when "date_sub"
      t = Time.parse(args[0]) - args[1].to_i
      return t.strftime (args.length>2 ? args[2] : "%Y-%m-%d %H:%M %Z")
    when "to_csv"
      return args.join(",")
    when "concat"
      return args.join("")
    when "exp"
      return args[0].to_f ** args[1].to_f
    when "abs"
      return args[0].to_f.abs
    when "gsub"
      return args[0].to_s.gsub(/#{Regexp.new(args[1].to_s)}/,args[2].to_s)
    when "match"
      return (args[0].to_s.match(/#{Regexp.new(args[1].to_s,true)}/).nil?) ? 0 : 1
    when "upcase"
      return args[0].to_s.upcase
    when "downcase"
      return args[0].to_s.downcase
    when "length"
      return args[0].to_s.length
    when "strip"
      return args[0].to_s.strip
    when "lt"
      return cmp(args[0],args[1]) { |a,b| a < b }
    when "le"
      return cmp(args[0],args[1]) { |a,b| a <= b }
    when "gt"
      return cmp(args[0],args[1]) { |a,b| a > b }
    when "ge"
      return cmp(args[0],args[1]) { |a,b| a >= b }
    when "eq"
      return cmp(args[0],args[1]) {|a,b| a==b}
    when "ne"
      return cmp(args[0],args[1]) { |a,b| a != b }
    when "if"
      args[0] = 0 if FalseClass === args[0]
      args[0] = 1 if TrueClass === args[0]
      return args[0].to_i != 0 ? args[1] : args[2]
    when 'and'
      return args.map {|v| v && v.to_i != 0}.reduce(true) {|res,v| res && v }
    when 'or'
      return args.map {|v| v && v.to_i != 0}.reduce(false) {|res,v| res || v }
    when "json_lookup"
      json = JSON.parse(args[0])
      if json.has_key?(args[1]) then
        value = json[args[1]]
        return (value.class.name == "Hash" ? value.to_json : value)
      else
        if args.length>2 then
          return args[2]
        else
          raise ArgumentError.new("#{args[1]} is not a key in the given JSON")
        end
      end
    when "is_empty"
      return args[0].to_s.length>0 ? args[0] : args[1]
    else
      if exops then
        return exops.call(op,args)
      else
        raise "Unknown function: #{op}"
      end
    end
  end

end

