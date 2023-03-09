# MINIMAL TODO LIST
# x if statements and comparisons
# - for & while
# - floats
# x strings
# x lists
# - factors & multiplication
# - minimal test suite
# - shell interop
# - refactor call system; minimally:
#   - __getitem__ []
#   - __add__ +
#   - __eq__ == (and other comps)
#   - __repr__

# NEXT LEVEL
# - conversions to strings, especially for ints/floats
# - dictionaries
# - interpreter & .pop file ingestion

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


set -e
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
    input="$1"
    return $(test "x${input:0:3}" = "xINT")
    }


read_braces_block(){
    local nopen=1
    rv=()
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
        rv+=($current_token)
        advance
    done
    rv="${rv[@]}"
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
    local pending_assignment=0 leftid rightval

    read -ra tokens <<< $1
    echo "Parsing the following tokens: ${tokens[@]}"

    local itoken="-1" ; advance # initialize

    eat_sep
    while strneq "${current_token}" "EOF" ; do
        rv="NULL"
        if maybe_eat "IF" ; then
            if_statement
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


if_statement(){
    echo "New if statement"

    local code_to_be_executed the_boolean the_code_block
    local looking_for_code_to_execute=1

    expr_with_comp ; the_boolean="$rv"
    eat_sep
    eat "PNC{"
    read_braces_block ; local the_code_block="$rv"
    eat_sep

    if strneq $the_boolean "INT0" ; then
        looking_for_code_to_execute=0
        code_to_be_executed="$the_code_block"
    fi

    while maybe_eat "ELIF" ; do
        
        expr_with_comp ; the_boolean="$rv"
        eat_sep
        eat "PNC{"
        read_braces_block ; local the_code_block="$rv"
        eat_sep

        if test $looking_for_code_to_execute -eq 1 && strneq $the_boolean "INT0" ; then
            looking_for_code_to_execute=0
            code_to_be_executed="$the_code_block"
        fi
    done

    if maybe_eat "ELSE" ; then
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

        # Expand to array again (read_braces_block returns space-sep string)
        local insert_tokens
        read -ra insert_tokens <<< $code_to_be_executed

        # Throw away processed tokens, prefix the tokens from the if_statement.
        # current_token and next_token should not be affected.
        # This is a very inefficient operation.
        tokens=( "SEP" "${insert_tokens[@]}" "SEP" "SEP" "${tokens[@]:$itoken}" )
        itoken=0
        echo "Token stream changed to: ${tokens[@]}"
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

            # Handle builtins
            if streq "$fnid" "IDprint" ; then
                for arg in ${args[@]}; do
                    resolve_id $arg ; local printstr="$rv"

                    # FIXME: Normally object would be printed as e.g. "OBJ11".
                    # This code only resolves for strings.
                    # It would probably be better to check for the existence of a __repr__ method
                    # for the object (or parent class).
                    _resolve "$printstr"
                    if streq "$rv" "STR" ; then
                        resolve_id "${printstr}IDstr" ; printstr="$rv"
                    fi

                    echo ">>> POPOUT: $printstr"
                done
                rv="NULL"
                return 0
            elif streq "$fnid" "STRIDlength" ; then
                resolve "${owner_obj}IDstr"
                rv="INT${#rv}"
                return 0
            fi

            resolve_id $fnid ; local fn_obj=$rv

            local tmp="${args[@]}"
            if streq "${fn_obj:0:5}" "CLASS" ; then
                instantiate "$fnid" "$tmp"
            else
                call "$fnid" "$tmp"
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
        _new_obj ; local obj=$rv
        export "$obj"="STR"
        local strval=$(echo "${current_token:3}" | tr "~" " ")
        export "${obj}IDstr"="$strval"
        echo "Init $obj=STR ${obj}IDstr=$strval"
        advance
    else
        error "expected an ID but found $current_token"
    fi
    }


list(){
    echo "Init list"
    _new_obj ; local obj="$rv"
    export "$obj"="LIST"
    
    local elements=()

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
    export "${obj}IDelements"=$elements
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
        error "cannot add $val1 and $val2"
    fi
    }


call(){
    local fnid=$1
    local args arg i fn_args
    read -ra args <<< $2

    if strempty $fnid ; then
        error "found no function $fnid"
    elif streq "$fnid" "IDprint" ; then
        for arg in ${args[@]}; do
            resolve_id $arg
            echo ">>> POPOUT: $rv"
        done
        return 0
    fi

    resolve_id $fnid ; local obj="$rv"
    resolve_id "${obj}ID__args__"
    if streq $rv "NULL" ; then
        fn_args=()
    else
        read -ra fn_args <<< $rv
    fi
    resolve_id "${obj}ID__tokens__"; local fn_code="$rv"

    echo "Called function $fnid with arguments ${args[@]}"
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
    if strnempty $init_method ; then
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
