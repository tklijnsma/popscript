_add_current_token(){
    local token="$1"
    # First catch empty tokens
    if [ -z "$token" ]; then
        return
    # Check for keywords
    elif [[ "$token" == "def" ]]; then
        echo "DEF"
    elif [[ "$token" == "return" ]]; then
        echo "RET"
    elif [[ "$token" == "for" ]]; then
        echo "FOR"
    elif [[ "$token" == "while" ]]; then
        echo "WHL"
    elif [[ "$token" == "if" ]]; then
        echo "IF"
    elif [[ "$token" == "elif" ]]; then
        echo "ELIF"
    elif [[ "$token" == "else" ]]; then
        echo "ELSE"
    elif [[ "$token" == "class" ]]; then
        echo "CLASS"
    elif [[ "$token" == "null" ]]; then
        echo "NULL"
    # Check for str
    elif test "x${token:0:3}" = "xSTR" ; then
        echo "$token"
    # Check for int
    elif [ "$token" -eq "$token" ] 2> /dev/null ; then
        echo "INT$token"
    # Finally, if all else passed, it's an ID
    else
        echo "ID$token"
    fi
    }

_tokenize_line(){
    local line=$1
    local i=0
    local len=${#line}
    local strmode=0

    local token=""

    while (($i < $len)); do
        local c="${line:$i:1}"
        local next_c="${line:$((i+1)):1}"

        if test $strmode = 1 ; then
            if [[ "$c" == "\"" ]]; then
                # Close the string
                _add_current_token "$token" ; token=""
                strmode=0
            elif [[ "$c" == " " ]]; then
                token="${token}~"
            elif [[ "$c" == "~" ]]; then
                token="${token}\~"
            else
                token="${token}$c"
            fi
        elif [[ "$c" == "\"" ]]; then
            strmode=1
            _add_current_token $token ; token="STR"
        elif [[ "$c" == " " ]]; then
            # Hit whitespace: Add current token and reset
            _add_current_token $token ; token=""
        elif [[ "$c" == "#" ]]; then
            # Hit comment: Add current token and exit
            _add_current_token $token
            return
        elif [[ "$c" == ";" ]]; then
            # Treat ; as separators
            _add_current_token $token ; token=""
            echo "SEP"
        elif [[ "$c" == "<" || "$c" == ">" ]]; then
            _add_current_token $token ; token=""
            if [[ "$next_c" == "=" ]]; then
                echo "COMP$c="
                test $((i++))  # extra skip
            else
                echo "COMP$c"
            fi
        elif [[ "$c" == "!" ]]; then
            _add_current_token $token ; token=""
            if [[ "$next_c" == "=" ]]; then
                echo "COMP!="
                test $((i++)) # extra skip
            else
                echo "ERROR sole ! is illegal syntax"
                return 1
            fi
        elif [[ "$c" == "=" ]]; then
            _add_current_token $token ; token=""
            if [[ "$next_c" == "=" ]]; then
                echo "COMP=="
                test $((i++)) # extra skip
            else
                echo "PNC="
            fi
        elif [[ ",][]}{)(+-.*/" == *"$c"* ]]; then
            # Hit punctuation: Add current token, yield punctuation, and reset
            _add_current_token $token ; token=""
            echo "PNC$c"
        else
            # No special character; add to the current token and continue
            token="${token}$c"
        fi
        test $((i++)) # next char
    done
    _add_current_token $token # Add any remaining token
    echo "SEP" # Every line end is a separator
    }


tokenize(){
    # Read from file or stdin
    local line
    while read -r line; do
        # echo "Tokenizing line $line"
        _tokenize_line "$line"
    done < "${1:-/dev/stdin}"
    }
