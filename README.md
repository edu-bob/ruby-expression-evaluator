# Prefix expression evaluator

## Introduction

This is a simple expression evaluator for expressions like you would use in Excel.  It's useful if you want to
and expression into, say, JSON, and just want to write it out rather than making some complicated tree
structure in JSON for the expression.  A recommended use is to allow for it to be used anywhere a string is
used, and flagged by the string starting with an equal sign, like in Excel.  Strip off the eual sign and
send the rest to this gem.

Expressions are in prefix, or function, notation (like Excel).  All operators (add, multiply, etc) are expressed
like function calls, e.g.
```
add(mult(0.4, 27), mult(0.6, 33))
```
Values in expressions can be numeric constants or quoted strings (double quotes only).
As the caller, you can provide a "string expander" function that all strings will
be passed through diring interpretation.  This can be used, for example to implement
a "macro" facility such that strings could have placeholders in them, for example
     "{term_start} PST"
can be expanded by the caller-provided string expander.  See HOW TO USE below.

As of the initial writing, the supported function are
```
mod, sub, div, add, mult, date_add, date_sub, to_csv, concat,
exp, abs, gsub, upcase, downcase, length, strip, match,
lt, le, gt, ge, eq, ne, if, and, or, json_lookup, is_empty
```

## Building and Testing

### How to Build the gem
```
gem build expressions.gemspec  && gem install ./expressions-0.1.0.gem 
```
### Testing

Evaluate just one expression
```
ruby -e "require 'expressions';puts Expressions.evaluate('add(mult(add(1,1),3),4,add(5,6))',verbosity=2)"
```

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
  # Expand str and return the expansion.  Return the original placeholder or and empty string if unknown placeholder
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

