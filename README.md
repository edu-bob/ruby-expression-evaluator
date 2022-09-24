# Prefix expression evaluator

## Introduction

Expressions are in prefix, or function, notation.  All operators (add, multiply, etc) are expressed
like function calls, e.g.
```
add(mult(0.4, 27), mult(0.6, 33))
```
Values in expressions can be numeric constants or quoted strings (double quotes only).
As the caller, you can provide a "string expander" function that all strings will
be passed through diring interpretation.  This can be used, for example to implement
a "macro" facility such that strings could have placeholders in them, for example
     "{term_start} PST"
can be expanded for the caller-provided string expander.  See HOW TO USE below.

## Building and Testing

### Build the gem
```
gem build expressions.gemspec  && gem install ./expressions-0.1.0.gem 
```
### Testing

Evaluate just one expression
    ruby -e "require 'expressions';puts Expressions.evaluate('add(mult(add(1,1),3),4,add(5,6))',verbosity=2)"

Read expressions from STDIN, for testing
```
ruby tester.rb
```

Read from named file, for testing
```
ruby tester.rb test-scripts
```

## How to Use

To see known functions:
```
 ruby -e "require 'expressions';puts Expressions.functions"
```

To use in your own code

1. `require 'expressions'`
2. If you're using a string expander, define a lambda to expand strings
```
    doExpand = lambda do |str|
    # Expand str and return the expansion
    end
```
4. If you have external functions that you want to add to expressions, define a lambda to handle them. For example
```
    extraOps = lambda do |op,args|
      case op
      when "rev"
	return args[0].to_s.reverse()
      else
        raise "Unkownn function: #{op}(#{args.join(',')})"
      end
    end
```
3. Call the evaluator on your expression; it returns the computed value
```
result = Expressions.evaluate(line, doExpand, extraOps)
```

