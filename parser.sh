# MINIMAL TODO LIST
# - floats (incl negative)
# - factors, subtraction, and multiplication/division
# - change echo's to debug, and allow running without debug
# - minimal test suite
# - shell interop
# > refactor call system; minimally:
#   x __getitem__ []
#   x __add__ +
#   - __eq__ == (and other comps)
#   > __repr__ WIP!
# x negative ints (also in tokenizer)
# x while
# x continue
# x break
# x if statements and comparisons
# x for
# x strings
# x lists
# x range

# NEXT LEVEL
# - and/or
# - booleans
# - single quote strings
# - basic benchmarking
# - conversions to strings, especially for ints/floats
# - dictionaries
# - interpreter & .pop file ingestion
# - much better error messages
# - delete keyword

# ULTIMATELY
# - multiline strings
# - garbage collection
# - error handling
# - operator overloading
# - minimize source code to single file
# - unpacking tuples for return, for loops, ...
# - keyword arguments
# - inheritance
# - type(...) function


# set -e
source tokenizer.sh

rv=""
iobj=10
iclass=10
inside_class_def=0
inside_function=0
current_classnr=""
same_scope_as_parent_parser=0


_new_obj(){
    rv="OBJ${iobj}"
    ((iobj++))
    }

_new_class(){
    rv="CLASS${iclass}"
    ((iclass++))
    }

streq(){
    return $(test "x$1" = "x$2")
    }

strneq(){
    return $(test "x$1" != "x$2")
    }

strempty(){
    return $(test -z "$1")
    }

strnempty(){
    return $(test ! -z "$1")
    }

error(){
    echo "ERROR $1"
    exit 1
    }

advance(){
    ((itoken++))
    current_token="${tokens[$itoken]}"
    next_token="${tokens[$itoken+1]}"
    if strempty "$current_token" ; then current_token="EOF" ; fi
    if strempty "$next_token" ; then next_token="EOF" ; fi
    # echo "Advanced to itoken=$itoken current_token=${current_token}"
    if streq "$current_token" "EOF" && test ${#token_stack[@]} -gt 0 ; then
        # Current token stream exhausted but there is something on the stack
        pop_tokens
    fi
    }


push_tokens(){
    # Push the current set of tokens and the location of the current token to the stack
    token_str="SEP ${tokens[@]}" # Insert a SEP because the main interpreter loop wants to eat a SEP
    token_stack+=( "$token_str" )
    token_type_stack+=("$1")
    token_pickup_stack+=( $((itoken+1)) ) # Add 1 because of the inserted SEP
    # Overwrite the current token stream and reset
    local overwrite_token_str="SEP $2 SEP"
    read -ra tokens <<< $overwrite_token_str
    echo "Pushed to stack"
    echo "  token_stack=${token_stack[@]}"
    echo "  len token_stack=${#token_stack[@]}"
    echo "  token_pickup_stack=${token_pickup_stack[@]}"
    echo "  tokens=${tokens[@]} (starting at 0)"
    itoken="-1" ; advance
    }


pop_tokens(){
    local last="${#token_stack[@]}" ; ((last--))
    echo "Picking up previous stream; last=$last"
    # Get the tokens on top of the stack, and read them back into the current token stream
    tokens="${token_stack[$last]}"
    read -ra tokens <<< $tokens
    echo "  set current token stream to ${tokens[@]}"
    # Delete the last element of the token stack
    unset "token_stack[$last]"
    # Pop the index from which the current stream is supposed to be picked up
    itoken="${token_pickup_stack[$last]}"
    echo "  set itoken to $itoken"
    unset "token_pickup_stack[$last]"
    unset "token_type_stack[$last]"
    # Reset
    ((itoken--))
    advance
    echo "  itoken=$itoken current_token=$current_token next_token=$next_token"
    }

eat(){
    local token
    for token in "$@" ; do
        if streq "$current_token" "$token" ; then
            advance
            return 0
        fi
    done
    error "expected $@ but got ${current_token}"
    }

maybe_eat(){
    local token
    for token in "$@" ; do
        if streq "$current_token" "$token" ; then
            advance
            return 0
        fi
    done
    return 1
    }

eat_sep(){
    while streq "$current_token" "SEP" ; do
        advance
    done
    }

eat_superfluous_sep(){
    while streq "$current_token" "SEP" && streq "$next_token" "SEP" ; do
        advance
    done
    }


_resolve(){
    # Does a single resolve on a variable.
    # Does not check if the resolution is empty.
    # THIS FUNCTION IS NOT POSIX COMPLIANT YET
    local rid="$1"
    if strempty "$rid" ; then
        error "empty string"
    fi
    # BASH ONLY! See https://unix.stackexchange.com/a/251896/183009
    rv=${!rid}
    }


resolve_id(){
    # If $1 contains the substring "ID", does a resolve, otherwise
    # does nothing.
    local rid="$1"
    if strempty "$rid" ; then
        error "empty string"
    fi

    case "$rid" in
    # BASH ONLY! See https://unix.stackexchange.com/a/251896/183009
    *ID*) _resolve $rid ;;
    *)    rv=$rid ;;
    esac

    # Check if it succeeded
    if strempty "$rv" ; then
        error "failed to resolve $rid"
    else
        echo "Resolved $rid to $rv"
    fi
    }


resolve(){
    # Like resolve_id, but forces a resolve
    local rid="$1"
    if strempty "$rid" ; then
        error "empty string"
    fi

    _resolve $rid

    # Check if it succeeded
    if strempty "$rv" ; then
        error "failed to resolve $rid"
    else
        echo "Resolved $rid to $rv"
    fi
    }


exists(){
    # Checks if variable is defined
    local rid="$1"
    if strempty "$rid" ; then
        error "empty string"
    fi
    _resolve $rid
    return $(strnempty "$rv")
    }


not_exists(){
    # Checks if variable is NOT defined
    local rid="$1"
    if strempty "$rid" ; then
        error "empty string"
    fi
    _resolve $rid
    return $(strempty "$rv")
    }


is_int(){
    local input="$1"
    return $(test "x${input:0:3}" = "xINT")
    }

assert_int(){
    local input="$1"
    if strneq "${input:0:3}" "INT" ; then
        error "expected INT but got $input"
    fi
    }

read_braces_block(){
    local nopen=1
    local tokens_in_braces=()
    while : ; do
        if maybe_eat "EOF" ; then
            error "reached EOF while scanning tokens"
        elif streq "$current_token" "PNC{" ; then
            ((nopen++))
        elif streq "$current_token" "PNC}" ; then
            ((nopen--))
            if test $nopen -eq 0 ; then
                advance
                break
            fi
        fi
        tokens_in_braces+=($current_token)
        advance
    done
    rv="${tokens_in_braces[@]}"
    }


run(){
    local code="$1"
    echo "Running the following code:"
    echo "$code"
    echo ""

    local token_string=$(echo "$code" | tokenize)
    # echo "which is the following tokens: $token_string"
    # echo ""

    parse "$token_string"
    }


parse(){
    local current_token next_token tokens
    local token_stack=()
    local token_pickup_stack=()
    local token_type_stack=()
    local pending_assignment=0 leftid rightval

    # If we encounter a continue or break, we need to know
    # whether we're in a for or a while loop
    local loop_stack=()

    # For the while-loop, we only need to know the conditional
    # (in order to reevaluate it)
    local while_loop_conditional_stack=()

    # The for-loop needs 3 pieces of information:
    # - the iterable (list) of items;
    # - the location of where it's at in the list now
    # - the ID of where it should put the next item
    local for_loop_iterable_stack=()
    local for_loop_index_stack=()
    local for_loop_iterid_stack=()

    read -ra tokens <<< $1
    echo "Parsing the following tokens: ${tokens[@]}"

    local itoken="-1" ; advance # initialize

    eat_sep
    while strneq "${current_token}" "EOF" ; do
        rv="NULL"
        if maybe_eat "IF" ; then
            if_statement
        elif maybe_eat "FOR" ; then
            for_statement
        elif maybe_eat "LOOPFOR" ; then
            loopfor
        elif maybe_eat "WHILE" ; then
            while_statement
        elif maybe_eat "LOOPWHILE" ; then
            loopwhile
        elif maybe_eat "CONTINUE" ; then
            continue_loop
        elif maybe_eat "BREAK" ; then
            break_loop
        elif maybe_eat "CLASS" ; then
            define_class
        elif maybe_eat "DEF" ; then
            define_fn
        elif maybe_eat "RET" ; then
            if test $inside_function -eq 0 ; then
                error "return outside of function"
            fi
            ((inside_function--))
            expr_or_assignment
            echo "Return value before resolving: $rv"
            resolve_id "$rv"
            echo "Return value: $rv"
            break
        else
            expr_or_assignment
        fi

        # Do pending assignments
        if test $pending_assignment -ne 0 ; then
            # 1 means local assignment,
            # 2 means global: always skip "local" kw
            if test $pending_assignment -eq 1 ; then
                local "$leftid"
                echo "Local assignment $leftid = $rightval"
            else
                echo "Global assignment $leftid = $rightval"
            fi
            # Assign the actual id, and revert $pending_assignment back to 0
            export "$leftid"="$rightval"
            pending_assignment=0
        fi

        eat "SEP" "EOF"
        eat_sep
    done
    }


continue_loop(){
    echo "Hit continue"
    # Pop out of any if's
    echo "  token_type_stack=${token_type_stack[@]}"
    local peek=${token_type_stack[${#token_type_stack[@]}-1]}
    while streq $peek  "if" ; do
        echo "  in if-subscope, popping out"
        pop_tokens
        peek=${token_type_stack[${#token_type_stack[@]}-1]}
    done
    # Loop
    local peek=${loop_stack[${#loop_stack[@]}-1]}
    if streq "$peek" "for" ; then
        loopfor
    elif streq "$peek" "while" ; then
        loopwhile
    else
        error "encountered continue outside of a loop"
    fi
    }


break_loop(){
    echo "Hit break"
    # Pop out of any if's
    echo "  token_type_stack=${token_type_stack[@]}"
    local peek=${token_type_stack[${#token_type_stack[@]}-1]}
    while streq $peek  "if" ; do
        echo "  in if-subscope, popping out"
        pop_tokens
        peek=${token_type_stack[${#token_type_stack[@]}-1]}
    done
    # Break out of actual loop
    local peek=${loop_stack[${#loop_stack[@]}-1]}
    if streq "$peek" "for" ; then
        local last=${#for_loop_iterable_stack[@]} ; ((last--))
        unset "for_loop_iterable_stack[$last]"
        unset "for_loop_index_stack[$last]"
        unset "for_loop_iterid_stack[$last]"
        local last=${#loop_stack[@]} ; ((last--))
        unset "loop_stack[$last]"
        pop_tokens
    elif streq "$peek" "while" ; then
        local last=${#while_loop_conditional_stack[@]} ; ((last--))
        unset "while_loop_conditional_stack[$last]"
        pop_tokens
    else
        error "encountered break outside of a loop"
    fi
    }


for_statement(){
    echo "New for statement"

    eat_sep
    local iterid="$current_token"
    if strneq "${iterid:0:2}" "ID" ; then
        error "Expected ID but got $iterid"
    fi
    local "$iterid"
    advance

    eat_sep
    eat "IN"
    eat_sep

    expr_with_comp ; local iterable="$rv"
    eat_sep
    eat "PNC{"
    read_braces_block ; local for_body_code="SEP $rv SEP LOOPFOR SEP"

    call "${iterable}ID__getitem__" "INT0"
    local code="$?"
    if test $code -eq 1 ; then
        # No function __getitem__ defined
        error "not an iterable: $iterable"
    elif test $code -eq 21 ; then
        # IndexError: iterator is empty, don't start the loop
        :
    elif test $code -eq 0 ; then
        # Successfully called the first item, so start the for loop
        pending_assignment=1
        leftid="$iterid"
        rightval="$rv"

        push_tokens "for" "$for_body_code"
        loop_stack+=("for")
        for_loop_iterable_stack+=("$iterable")
        for_loop_index_stack+=(0)
        for_loop_iterid_stack+=("$iterid")
    else
        error "__getitem__ on $iterable failed: $code"
    fi
    }


loopfor(){
    echo "In loopfor; loop_stack=${loop_stack[@]}"
    # Check if we're actually in a for loop
    local last=${#loop_stack[@]} ; ((last--))
    if test $last -eq -1 || strneq "${loop_stack[$last]}" "for" ; then
        error "in loopfor but active loop is not for"
    fi
    # Get all the specifics of this for-loop from the stacks
    local last=${#for_loop_index_stack[@]} ; ((last--))
    local iterable="${for_loop_iterable_stack[$last]}"
    local i="${for_loop_index_stack[$last]}"
    local iterid="${for_loop_iterid_stack[$last]}"
    ((i++))
    for_loop_index_stack[$last]=$i

    call "${iterable}ID__getitem__" "INT$i"
    local code="$?"
    echo "  __getitem__ call has status code $code"
    if test $code -eq 0 ; then
        # Next item well received; revert to beginning of the for loop
        pending_assignment=1
        leftid="$iterid"
        rightval="$rv"
        itoken=0
        echo "  next item $i, set itoken to $itoken"
    elif test $code -eq 21 ; then
        # IndexError: Must have reached end of iterable
        echo "  reached end at $i, exiting for-loop"
        unset "for_loop_iterable_stack[$last]"
        unset "for_loop_index_stack[$last]"
        unset "for_loop_iterid_stack[$last]"
        local last=${#loop_stack[@]} ; ((last--))
        unset "loop_stack[$last]"
    else
        error "failed __getitem__ for $iterable"
    fi
    }


while_statement(){
    echo "New while statement"
    eat_sep


    local itoken_before_conditional=$itoken
    expr_with_comp ; the_boolean="$rv"
    local itoken_after_conditional=$itoken

    eat_sep
    eat "PNC{"
    read_braces_block ; local the_code_block="$rv"
    
    if strneq $the_boolean "INT0" ; then
        # Start the while loop
        # Collect all the tokens that made up the conditional:
        local n=$(($itoken_after_conditional-$itoken_before_conditional))

        local tokens_for_conditional="${tokens[@]:$itoken_before_conditional:$n}"
        echo "  using the following tokens as the conditional: ${tokens_for_conditional[@]}"
        while_loop_conditional_stack+=("${tokens_for_conditional[@]}")

        push_tokens "while" "$the_code_block SEP LOOPWHILE SEP"
        loop_stack+=("while")
    fi
    }


loopwhile(){
    local last=${#loop_stack[@]} ; ((last--))
    if test $last -eq -1 || strneq "${loop_stack[$last]}" "while" ; then
        error "in loopwhile but active loop is not while"
    fi

    local last=${#while_loop_conditional_stack[@]} ; ((last--))
    local conditional="${while_loop_conditional_stack[$last]}"

    parse "$conditional" ; the_boolean="$rv"
    echo "outcome of conditional: $the_boolean"

    if strneq $the_boolean "INT0" ; then
        echo "loopwhile: going back to itoken=0"
        itoken=-1
        advance
        echo "$itoken $current_token $next_token ---- ${tokens[@]}"
    else
        echo "loopwhile: exiting loop"
        unset "while_loop_conditional_stack[$last]"
    fi
    }


if_statement(){
    echo "New if statement"

    local code_to_be_executed the_boolean the_code_block
    local looking_for_code_to_execute=1

    expr_with_comp ; the_boolean="$rv"
    eat_sep
    eat "PNC{"
    read_braces_block ; local the_code_block="$rv"
    eat_superfluous_sep

    if strneq $the_boolean "INT0" ; then
        looking_for_code_to_execute=0
        code_to_be_executed="$the_code_block"
    fi

    while streq "$current_token" "ELIF" || ( streq "$current_token" "SEP" && streq "$next_token" "ELIF" )
    do    
        eat_sep
        eat "ELIF"
        expr_with_comp ; the_boolean="$rv"
        eat_sep
        eat "PNC{"
        read_braces_block ; local the_code_block="$rv"
        eat_superfluous_sep

        if test $looking_for_code_to_execute -eq 1 && strneq $the_boolean "INT0" ; then
            looking_for_code_to_execute=0
            code_to_be_executed="$the_code_block"
        fi
    done

    if streq "$current_token" "ELSE" || ( streq "$current_token" "SEP" && streq "$next_token" "ELSE" )
    then
        eat_sep
        eat "ELSE"
        eat_sep
        eat "PNC{"
        read_braces_block ; local the_code_block="$rv"
        if test $looking_for_code_to_execute -eq 1 ; then
            looking_for_code_to_execute=0
            code_to_be_executed="$the_code_block"
        fi
    fi

    if test $looking_for_code_to_execute -eq 0 ; then
        # Some code to execute was found
        echo "Running the following code: $code_to_be_executed"
        push_tokens "if" "$code_to_be_executed"
    else
        echo "No branch of if statement found to execute"
    fi
    }


define_class(){
    echo "Defining a new class"
    id ; local classid="$rv"

    if test $inside_class_def -eq 1 ; then
        error "already defining a class; nested classes currently not permitted"
    fi

    if strneq "${classid:0:2}" "ID" ; then
        error "expected id starting with ID but found $classid"
    fi

    _new_class ; local classnr=$rv
    export "${classnr}ID__name__"="${classid:2:100}"

    # Parse the class body
    eat_sep
    eat "PNC{"
    read_braces_block
    local class_def_code="${rv[@]}"

    inside_class_def=1
    current_classnr=$classnr
    parse "$class_def_code"
    inside_class_def=0
    current_classnr=""

    pending_assignment=1
    leftid="$classid"
    rightval="$classnr"
    echo "Pending assignment $leftid = $rightval"
    }


define_fn(){
    echo "Defining a new function"
    id ; local fnid="$rv"

    if strneq "${fnid:0:2}" "ID" ; then
        error "expected id starting with ID but found $fnid"
    fi

    eat_sep
    eat "PNC("
    eat_sep

    local fn_args=()
    if maybe_eat "PNC)" ; then
        :
    else
        while : ; do
            eat_sep
            id
            fn_args+=($rv)
            eat_sep
            if maybe_eat "PNC," ; then
                continue
            elif maybe_eat "PNC)" ; then
                break
            else
                echo "ERROR expected , or ) but got $current_token"
            fi
        done
    fi
    
    eat_sep
    eat "PNC{"
    read_braces_block ; local fn_code="$rv"

    _new_obj ; local obj=$rv
    export "$obj"="FN"
    export "${obj}ID__tokens__"="$fn_code"
    export "${obj}ID__name__"="${fnid:2}"

    # For some reason getting a space-separated string only works via a tmp variable 
    local tmp="${fn_args[@]}"
    if strempty "$tmp" ; then
        # If no input args, still write NULL; leaving it empty should be a bug
        export "${obj}ID__args__"="NULL"
    else
        export "${obj}ID__args__"="$tmp"
    fi

    if test $inside_class_def -eq 1 ; then
        # This function is a method; assign it in global scope
        echo "Assigning ${current_classnr}${fnid} = $obj"
        export "${current_classnr}${fnid}"="$obj"
    else
        # The assignment should only live in the current scope;
        # should be resolved in `parse`
        echo "Pending assignment $fnid = $obj"
        pending_assignment=1
        leftid="$fnid"
        rightval="$obj"
    fi

    # Debug printout
    echo "  $obj =" ${!obj}
    local tmp="${obj}ID__name__"
    echo "  ${obj}ID__name__ =" "${!tmp}"
    tmp="${obj}ID__args__"
    echo "  ${obj}ID__args__ =" "${!tmp}"
    tmp="${obj}ID__tokens__"
    echo "  ${obj}ID__tokens__ =" "${!tmp}"
    }


expr_or_assignment(){
    expr_with_comp
    if maybe_eat "PNC=" ; then
        echo "This is an assignment"
        leftid="$rv"
        expr_with_comp
        resolve_id "$rv"
        rightval="$rv"

        if test $inside_class_def -eq 1 && streq "${leftid:0:2}" "ID" ; then
            pending_assignment=2
            leftid="${current_classnr}${leftid}"
        else
            if streq "${leftid:0:2}" "ID" ; then
                # Independent variable
                pending_assignment=1
            else
                # Attribute of an object
                pending_assignment=2
            fi
        fi
        echo "Pending assignment $leftid = $rightval ($pending_assignment)"
    fi
    }


expr_with_comp(){
    expr
    if streq "${current_token:0:4}" "COMP" ; then
        resolve_id $rv ; local left_val="$rv"
        local comp_token="$current_token"
        advance
        echo "Detected comparison $comp_token"
        expr
        resolve_id $rv ; local right_val="$rv"
        
        local left_type="${left_val:0:3}"
        local right_type="${right_val:0:3}"
        local left_value="${left_val:3}"
        local right_value="${right_val:3}"
        local op="${comp_token:4}"

        if ( streq $left_type "INT" || streq $left_type "FLT" ) && \
            ( streq $right_type "INT" || streq $right_type "FLT" ) ; then
            # Defer the actual comparison to bc; 1 means true, 0 means false
            rv=$(bc <<< "$left_value $op $right_value")
            rv="INT$rv"
        else
            error "TODO: string comparisons or op overloading not yet supported"
        fi

        echo "$left_val $comp_token $right_val = $rv"
    fi
    }


expr(){
    composed_id
    if maybe_eat "PNC+" ; then
        echo "Found addition"
        left_rv="$rv"
        composed_id
        right_rv="$rv"
        add "$left_rv" "$right_rv"
    fi
    }


composed_id(){
    id

    while : ; do

        if maybe_eat "PNC." ; then
            # Get the underlying object for current ID
            local old_rv=$rv
            resolve_id $rv ; local before_dot=$rv
            id
            rv="${before_dot}$rv"
            echo "get attribute: $old_rv --> $rv"

        elif maybe_eat "PNC(" ; then
            local fnid="$rv"
            echo "Detected callable $fnid"
            eat_sep
            # Parse arguments
            local args=()
            if maybe_eat "PNC)" ; then
                # No function arguments
                :
            else
                while : ; do
                    eat_sep
                    expr_with_comp
                    args+=("$rv")
                    eat_sep
                    if maybe_eat "PNC)" ; then
                        # Finished parsing arguments
                        break
                    elif maybe_eat "PNC," ; then
                        # Move on to next argument
                        continue
                    else
                        error "Expected ) or , but got $current_token"
                    fi
                done
            fi

            local tmp="${args[@]}"
            if call "$fnid" "$tmp" ; then
                # Function call worked out - all good
                :
            else
                # return code >0 means function call failed
                error "call to $fnid failed"
            fi

        elif maybe_eat "PNC[" ; then
            # Shorthand for __getitem__
            # Get the underlying object for current ID
            resolve_id $rv ; local obj=$rv
            # Solve the expression that is the index
            expr_with_comp ; local index="$rv"
            eat "PNC]"
            if call "${obj}ID__getitem__" "$index" ; then
                # All is well - no op
                :
            else
                error "failed to getitem $index for $obj"
            fi

        else
            break
        fi
    done
    }

id(){
    if maybe_eat "PNC[" ; then
        list
    elif test "${current_token:0:2}" = "ID" || test "${current_token:0:3}" = "INT" ; then
        rv="$current_token"
        echo "Found ID $current_token"
        advance
    elif test "${current_token:0:3}" = "STR" ; then
        newstr "$(echo "${current_token:3}" | tr "~" " ")"
        advance
    else
        error "expected an ID but found $current_token"
    fi
    }


newstr(){
    _new_obj ; local obj=$rv
    export "$obj"="STR"        
    export "${obj}IDstr"="$1"
    echo "New string $obj w/ ${obj}IDstr=$1"
    }


list(){
    echo "Init list"
    _new_obj ; local obj="$rv"
    export "$obj"="LIST"
    
    # Always have a default first argument "x" to prevent confusion
    # when dealing with empty lists
    local elements=(x)

    eat_sep
    if maybe_eat "PNC]" ; then
        : # no op
    else
        while : ; do
            eat_sep
            expr_with_comp ; elements+=("$rv")
            if maybe_eat "PNC," ; then
                continue
            elif maybe_eat "PNC]" ; then
                break
            else
                error "Expected ] , but got $current_token"
            fi
        done
    fi
    local tmp="${elements[@]}"
    export "${obj}IDelements"="$tmp"
    rv=$obj
    echo "Parsed list $obj: ${elements[@]}"
    }


# __________________________________________________________________________

add(){
    if strempty "$1" || strempty "$2" ; then
        error "empty string in addition"
    fi

    resolve_id "$1"
    local val1="$rv"
    resolve_id "$2"
    local val2="$rv"

    if is_int $val1 && is_int $val2 ; then
        int1="${val1:3:100}"
        int2="${val2:3:100}"
        rv="INT$(($int1+$int2))"
        echo "Added $val1 + $val2 = $rv"
    else
        if call "${val1}ID__add__" "$val2" ; then
            # __add__ method succeeded
            :
        else
            error "cannot add $val1 and $val2"
        fi
    fi
    }


call(){
    local fnid=$1
    local args arg i fn_args
    read -ra args <<< $2

    if streq "${fnid:0:3}" "OBJ" && not_exists $fnid ; then
        # We're trying to access an object method (e.g OBJ11ID__init__),
        # but it doesn't exist.
        # We should elevate to the CLASS of the object, and check if that
        # exists.
        local old_fnid=$fnid
        local owner_obj=${fnid%%ID*}
        local fnname=${fnid##*ID}
        resolve $owner_obj ; local classnr=$rv
        fnid="${classnr}ID$fnname"
        echo "Elevating unfound $old_fnid to $fnid and inserting $owner_obj as first arg"
        args=($owner_obj "${args[@]}")
    fi

    local argstr="${args[@]}"

    # Handle builtin class methods - INT, STR, FLT, etc.
    if streq "${fnid:0:3}" "INT" ; then
        int_methods "$fnid" "$argstr"
        return $?
    elif streq "${fnid:0:3}" "STR" ; then
        str_methods "$fnid" "$argstr"
        return $?
    elif streq "${fnid:0:4}" "LIST" ; then
        list_methods "$fnid" "$argstr"
        return $?
    # Handle builtin functions
    elif streq "$fnid" "IDprint" ; then
        printfn "$2"
        return 0
    elif streq "$fnid" "IDrange" ; then
        range "$2"
        return 0
    # elif streq "$fnid" "STRIDlength" ; then
    #     resolve "${owner_obj}IDstr"
    #     rv="INT${#rv}"
    #     return 0
    fi

    # If we reach this point, the function must be user-defined,
    # and thus must exist.
    if not_exists $fnid ; then
        echo "No such function: $fnid"
        return 1
    fi

    resolve_id $fnid ; local fn_obj=$rv

    if streq "${fn_obj:0:5}" "CLASS" ; then
        instantiate "$fnid" "$argstr"
    else
        parse_user_defined_fn "$fnid" "$argstr"
    fi
    }


parse_user_defined_fn(){
    local fnid=$1
    local args arg i fn_args
    read -ra args <<< $2

    resolve_id $fnid ; local obj="$rv"
    resolve_id "${obj}ID__args__"
    if streq $rv "NULL" ; then
        fn_args=()
    else
        read -ra fn_args <<< $rv
    fi
    resolve_id "${obj}ID__tokens__"; local fn_code="$rv"

    echo "Called user-defined function $fnid with arguments ${args[@]}"
    echo "  function arguments: ${fn_args[@]}"
    echo "  function code body: $fn_code"

    # Check if number of passed arguments matches function signature
    if test "${#args[@]}" -ne "${#fn_args[@]}" ; then
        resolve_id "${obj}ID__name__"; local fn_name="$rv"
        error "Function $fn_name ($fnid) expects ${#fn_args[@]} arguments but got ${#args[@]}"
    fi

    # Set function arguments in local scope
    for i in ${!args[@]}; do
        local "${fn_args[$i]}" # define the ID of the argument locally
        resolve_id "${args[$i]}" # resolve the rightval
        export "${fn_args[$i]}"="$rv" # actually set the ID to the value
        echo "  Defining fn arg ${fn_args[$i]} = $rv"
    done

    # Run the function; return value should be already set correctly
    ((inside_function++))
    parse "$fn_code"
    echo "Back in parent scope: current_token=$current_token, itoken=$itoken rv=$rv"
    }


instantiate(){
    local classid=$1
    local args
    read -ra args <<< $2

    resolve_id $classid ; local classnr=$rv

    _new_obj ; local obj=$rv
    export "$obj"=$classnr

    echo "Instantiating class $classid ($classnr) to $obj with args ${args[@]}"

    local init_method="${classnr}ID__init__"
    if exists $init_method ; then
        # An __init__ method is defined, use it
        # Add obj as the first argument
        args=("$obj" "${args[@]}")
        tmp="${args[@]}" # Make it a string
        call $init_method "$tmp"
    elif test "${#args[@]}" -ne 0 ; then
        error "class $classid does not take any arguments"
    fi

    rv=$obj
    }


printfn(){
    local args arg obj
    read -ra args <<< $1

    for arg in ${args[@]}; do
        resolve_id $arg ; local obj="$rv"

        if streq "${obj:0:3}" "OBJ" ; then
            if call "${obj}ID__repr__" ; then
                # repr method worked, print rv
                printstr="$rv"
            else
                # No repr method, print simply the obj
                printstr="$obj"
            fi
        else
            # Must be a builtin (e.g. INT), just print as is
            printstr="$obj"
        fi

        echo ">>> POPOUT: $printstr"
    done
    rv="NULL"
    return 0
    }


range(){
    local args begin end step
    read -ra args <<< $1
    local nargs="${#args[@]}"

    if test $nargs -eq 1 ; then
        begin=0
        resolve_id "${args[0]}" ; end="$rv"
        step=1
        assert_int $end ; end="${end:3}"
    elif test $nargs -eq 2 ; then
        resolve_id "${args[0]}" ; begin="$rv"
        resolve_id "${args[1]}" ; end="$rv"
        step=1
        assert_int $end ; end="${end:3}"
        assert_int $begin ; begin="${begin:3}"
    elif test $nargs -eq 3 ; then
        resolve_id "${args[0]}" ; begin="$rv"
        resolve_id "${args[1]}" ; end="$rv"
        resolve_id "${args[2]}" ; step="$rv"
        assert_int $end ; end="${end:3}"
        assert_int $begin ; begin="${begin:3}"
        assert_int $step ; step="${step:3}"
    else
        error "expected 1, 2, or 3 args but got $nargs"
    fi

    local elements=(x)
    for i in $(seq $begin $step $((end-1))) ; do
        elements+=("INT$i")
    done

    echo "Init list in range fn"
    _new_obj ; local obj="$rv"
    export "$obj"="LIST"    
    local elementstr="${elements[@]}"
    export "${obj}IDelements"="$elementstr"
    echo "Parsed range list $obj: ${elements[@]}"
    rv=$obj
    }


# BUILTIN METHOD IMPLEMENTATIONS

str_methods(){
    local fnid=$1
    local args
    read -ra args <<< $2
    local nargs="${#args[@]}"

    local obj="${args[0]}"
    resolve_id "${obj}IDstr" ; local str="$rv"

    if streq "$fnid" "STRID__repr__" ; then
        if test $nargs -ne 1 ; then
            error "expected 1 argument"
        fi
        rv="$str"
        # HIER VERDER
        # Dit klopt niet echt... __repr__ zou toch een string object moeten returnen,
        # En print() moet dan het str object converteren denk ik...
    elif streq "$fnid" "STRIDlength" ; then
        if test $nargs -ne 1 ; then
            error "expected 1 argument"
        fi
        rv="INT${#str}"
    elif streq "$fnid" "STRID__add__" ; then
        if test $nargs -ne 2 ; then
            error "expected 2 arguments"
        fi
        local rightobj="${args[1]}"
        resolve_id "${rightobj}IDstr"
        newstr "$str$rv"
    else
        echo "no such STR method: $fnid"
        return 1
    fi
    }

list_methods(){
    local fnid=$1
    local args
    read -ra args <<< $2
    local nargs="${#args[@]}"
    echo "Called list method $fnid with args ${args[@]}"

    local obj="${args[0]}"
    resolve_id "${obj}IDelements"
    local elements
    read -ra elements <<< $rv
    local nelements="${#elements[@]}"
    ((nelements--)) # Subtract 1 for the dummy element
    
    echo "  obj=$obj elements=${elements[@]}"

    if streq "$fnid" "LISTID__getitem__" ; then
        if test $nargs -ne 2 ; then
            error "expected 2 arguments"
        fi
        local index="${args[1]}"
        if strneq "${index:0:3}" "INT" ; then
            error "Expected integer for index but got $index"
        fi
        index="${index:3}"
        if test $index -ge $nelements ; then
            # error "index $index out of range $nelements"
            echo "  index=$index not in range (0-$nelements); return 21 (IndexError)"
            return 21 # indexerror
        fi
        ((index++)) # Increase by one because there is a dummy element
        rv="${elements[$index]}"
    elif streq "$fnid" "LISTIDlength" ; then
        if test $nargs -ne 1 ; then
            error "expected 1 argument"
        fi
        rv="INT$nelements"
    else
        echo "no such LIST method: $fnid"
        return 1  
    fi
    }