set h hello
set w world
puts "[set h] [set w]"; # Command subsitution: brackets are evaluated.
puts "$h $w"; # $ is short hand for [set x], it's "variable substitution"

set i 0
puts "Result: [ incr i; incr i; incr i ]"; # You can put multiple commands in a subsitution

set action pu
${action}ts "Hello world"; # Even commands are just strings
[set action]ts "Hello world"; # Crazy!

puts {$i $h $w}; # No substitutions in braces, these are literals!
if $i { puts $h$w }; # If conditionally evaluates the literal string

set l [list a b c d e]
puts [llength $l]
puts [lindex $l 0]

puts [expr {1 + 1}]; # Expr is used implicitly in control statements instead of prefix
puts [expr {1 < 2}]

# procedures can be defined
proc + {a b} {
    expr {$a + $b}
}
puts [+ 1 2]; # we can thus introduce prefix math notation into our language

# generalize with macros
# need to run list to immediately evaluate $o rather than deferring
set operators [list + - * /]
foreach o $operators {
    proc $o {a b} [list expr "\$a $o \$b"]; # option A
    # proc $o {a b} { expr \$a $o \$b };    # option B, doesn't work!
}
puts [/ 9 2]

foreach o $operators {
    proc ${o}v2 {} [list puts $o ];
}
puts [/v2]

# Braces and lists are the same thing?
eval {puts hello}
eval [list puts hello]
puts [llength {a b c}]

# Seems like it... list don't defer evaluation though
proc divide [list a b] [list expr {$a / $b}]
puts [divide 10 2]

proc repeat {n body} {
    while {$n} {
        # eval $body
        uplevel $body
        incr n -1
    }
}

repeat 5 { puts "hello five world" }

set a 0
repeat 5 { incr a }; # This only works with uplevel in repeat
puts $a


# Playing with higher-order procedures
proc listmap {i l f} { foreach $i $l { eval $f } }
listmap e {1 2 3 4 5} { set y [expr $e * $e]; puts $y }

# Re-implement without the foreach
proc listmap2 {i l f} {
    set n 0
    while {$n < [llength $l]} {
        set $i [lindex $l $n]
        eval $f
        incr n
    }
}
listmap2 e {1 2 3 4 5} { set y [expr $e * $e]; puts $y }

# Namespaces and variables
namespace eval people {
    variable a 1
    variable b 2

    proc print {} {
        puts "$people::a $people::b"
    }

    proc print2 {} {
        variable a
        variable b
        puts "$a $b"
    }
}

people::print
people::print2
