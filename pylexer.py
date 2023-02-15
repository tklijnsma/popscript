import pprint
import re
from contextlib import contextmanager


keywords = {
    'def' : 'DEF',
    'return' : 'RET',
    'for' : 'FOR',
    'while' : 'WHL',
    'if' : 'IF',
    'elif' : 'ELIF',
    'else' : 'ELSE',
    'class' : 'CLASS',
    'null' : 'NULL',
    }


def tokenize(lines):
    if isinstance(lines, str):
        lines = [lines]

    tokens = []
    token = ''

    def add_current_token():
        nonlocal token
        if token:
            if token in keywords:
                tokens.append(keywords[token])
            elif set(token).issubset(set('0123456789')):
                tokens.append('INT' + token)
            else:
                tokens.append('ID' + token)
            token = ''

    for line in lines:
        i = 0
        while i < len(line):
            c = line[i]
            next_c = line[i+1] if i < len(line)-1 else None

            if c == ' ':
                add_current_token()
            elif c == '\n' or c==';':
                add_current_token()
                tokens.append('SEP')
            elif c in '<>':
                add_current_token()
                tokens.append(f'COMP{c}')
                if next_c == '=':
                    tokens[-1] += '='
                    i += 1 # extra skip
            elif c == '!':
                add_current_token()
                if next_c != '=':
                    raise Exception('Sole ! is illegal syntax, must be followed by =')
                tokens.append('COMP!=')
                i += 1 # extra skip
            elif c == '=':
                add_current_token()
                if next_c == '=':
                    tokens.append('COMP==')
                    i += 1 # extra skip
                else:
                    tokens.append('PNC=')
            elif c in ',][]}{)(+-.*/':
                add_current_token()
                tokens.append('PNC'+c)
            elif c == '#':
                add_current_token()
                break
            else:
                token = token + c

            i += 1

        add_current_token()
        tokens.append('SEP')

    # tokens.append('EOF')
    return tokens


INDENT = 0


class EndMsg:
    def __init__(self, msg):
        self.msg = None

@contextmanager
def indented_print(msg, done=None):
    global INDENT
    endmsg = EndMsg(done)
    try:
        iprint(msg)
        INDENT += 1
        yield endmsg
    finally:
        if endmsg.msg: iprint(endmsg.msg)
        INDENT -= 1

def iprint(*args, **kwargs):
    print('  '*INDENT, end='')
    print(*args, **kwargs)


class Undefined(Exception):
    pass



GLOBALS = {}
LOCALS = {}
OPEN_MEM_SLOT = 10

def export(key, value):
    iprint(f'Assigning {key}={value} in global scope')
    global GLOBALS
    GLOBALS[key] = value

def local(key, value):
    iprint(f'Assigning {key}={value} in local scope')
    global LOCALS
    LOCALS[key] = value

def new_obj():
    global OPEN_MEM_SLOT
    rv = f'OBJ{OPEN_MEM_SLOT}'
    OPEN_MEM_SLOT += 1
    return rv

def new_class():
    global OPEN_MEM_SLOT
    rv = f'CLASS{OPEN_MEM_SLOT}'
    OPEN_MEM_SLOT += 1
    return rv

@contextmanager
def subscope():
    """
    Inherits the parent's local vars, but delete all local
    definitions upon exit
    """
    global LOCALS
    reset_LOCALS = LOCALS.copy()
    try:
        yield
    finally:
        LOCALS = reset_LOCALS


def parse(tokens, **kwargs):
    do_subscope = kwargs.pop('subscope', True)
    if do_subscope:
        with subscope():
            parser = Parser(**kwargs)
            return parser.parse(tokens)
    else:
        parser = Parser(**kwargs)
        return parser.parse(tokens)


class Parser:
    def __init__(self, inside_fn=False, inside_class_def=False, class_nr=None):
        self.current_token = None
        self.next_token = None
        self.inside_fn = inside_fn
        self.inside_class_def = inside_class_def
        self.class_nr = class_nr


    def defclass(self):
        # class Animal {
        #     def __init__(self){
        #         self.a = 3
        #         }

        #     def val(self){
        #         return self.a
        #         }
        #     }

        class_id = self.id()
        class_nr = new_class()

        iprint(f'Defining new class {class_id} = {class_nr}')
        local(class_id, class_nr)
        export(class_nr+'ID__name__', class_id[2:])

        self.eat_separators()
        class_body = self.read_braces_block()
        parse(class_body, inside_class_def=True, class_nr=class_nr)
        return 'NULL'


    def parse(self, tokens):
        rv = 'NULL'

        self.i = -1
        self.tokens = tokens
        self.advance()
        self.eat_separators()
        iprint(f'Starting at i={self.i}; curr_tok={self.current_token}, next_tok={self.next_token}')

        while self.i < len(self.tokens):
            with indented_print(f'Evaluating new line starting from token {self.current_token}') as msg:
                if self.maybe_eat('CLASS'):
                    if self.inside_class_def: raise Exception('For now, cannot define class inside other class')
                    self.defclass()
                elif self.maybe_eat('DEF'):
                    self.deffn()
                elif self.maybe_eat('RET'):
                    if not self.inside_fn:
                        raise Exception('Detected return statement outside a function')
                    rv = self.expr()
                    msg.msg = f'Line {rv=}'
                    return self.maybe_resolve_id(rv)
                elif self.maybe_eat('IF'):
                    rv = self.if_statement()
                else:
                    rv = self.expr()
                msg.msg = f'Line {rv=}'
            self.eat('SEP', 'EOF')
            self.eat_separators()
        return rv


    def read_braces_block(self):
        """
        Returns all tokens between matching {}
        """
        tokens = []
        self.eat('PNC{')
        open_braces = 1

        while True:
            if self.current_token == 'EOF' or self.current_token is None:
                raise Exception('Reached EOF with open brace')
            elif self.current_token == 'PNC{':
                open_braces += 1
            elif self.current_token == 'PNC}':
                open_braces -= 1
                if open_braces == 0:
                    self.eat('PNC}')
                    break
            tokens.append(self.current_token)
            self.advance()

        return tokens


    def read_parentheses_block(self):
        """
        Returns all tokens between matching ()
        """
        tokens = []
        self.eat('PNC(')
        open_parentheses = 1

        while True:
            if self.current_token == 'EOF' or self.current_token is None:
                raise Exception('Reached EOF with open parenthesis')
            elif self.current_token == 'PNC(':
                open_parentheses += 1
            elif self.current_token == 'PNC)':
                open_parentheses -= 1
                if open_parentheses == 0:
                    self.eat('PNC)')
                    break
            tokens.append(self.current_token)
            self.advance()

        return tokens



    def if_statement(self):
        looking_for_code_to_execute = True

        if_boolean = self.expr()
        self.eat_separators()
        if_code_block = self.read_braces_block()

        if if_boolean != 'INT0':
            looking_for_code_to_execute = False
            code_to_be_executed = if_code_block

        self.eat_separators()
        while self.maybe_eat('ELIF'):
            elif_boolean = self.expr()
            self.eat_separators()
            elif_code_block = self.read_braces_block()
            self.eat_separators()
            if looking_for_code_to_execute and elif_boolean != 'INT0':
                looking_for_code_to_execute = False
                code_to_be_executed = elif_code_block

        if self.maybe_eat('ELSE'):
            self.eat_separators()
            else_code_block = self.read_braces_block()
            if looking_for_code_to_execute:
                looking_for_code_to_execute = False
                code_to_be_executed = else_code_block

        if looking_for_code_to_execute:
            iprint('No part of the if-statement is run')
            rv = 'NULL'
        else:
            iprint('Running the following code block: ' + ' '.join(code_to_be_executed))
            rv = parse(
                code_to_be_executed,
                inside_fn=self.inside_fn, inside_class_def=self.inside_class_def,
                subscope=False
                )

        return rv



    def eat(self, *tokens):
        if self.current_token not in tokens:
            raise Exception(f'Expected {" ".join(tokens)} but got {self.current_token}')
        iprint(f'Eating {self.current_token}')
        self.advance()


    def maybe_eat(self, *tokens):
        if self.current_token in tokens:
            iprint(f'Eating {self.current_token}')
            self.advance()
            return True
        return False

    def eat_separators(self):
        while self.current_token == 'SEP':
            self.advance()

    def advance(self):
        self.i += 1
        self.current_token = self.tokens[self.i] if self.i < len(self.tokens) else 'EOF'
        self.next_token = self.tokens[self.i+1] if self.i+1 < len(self.tokens) else 'EOF'
        # iprint(f'Advanced to i={self.i}; curr_tok={self.current_token}, next_tok={self.next_token}')


    # a: V1
    # V1: INT
    # V1val: 3
    # V1__add__: V2
    # V2: FN
    # V2__call__: fn(self, o){...}

    # b: V3
    # V3: Cat
    # V3getpaw: V4
    # V4: FN
    # V4__call__: fn(self, o){...}

    def expr(self):
        """
        Resolves assignments
        """
        start = self.i
        with indented_print('Starting new expr'):
            rv = self.expr_level2()

            if self.maybe_eat('PNC='):
                iprint('This is an assignment')
                left_id = rv
                if left_id is None or not 'ID' in left_id:
                    raise Exception(f'Expected an ID on the left side of assignment, found {left_id}')
                # Move current token to what should be the next expression
                right_val = self.maybe_resolve_id(self.expr_level2())

                if self.inside_class_def and left_id.startswith('ID'):
                    class_var = self.class_nr + left_id
                    if class_var in GLOBALS:
                        # If class_var already exists, use class_var
                        export(class_var, right_val)
                    elif left_id in LOCALS:
                        # If class_var does not exist but a local one does exist, use 
                        # the local variable
                        local(left_id, right_val)
                    else:
                        # If neither exist assume this is a class_var def
                        export(class_var, right_val)
                else:
                    if left_id.startswith('ID'):
                        # It's a local variable
                        local(left_id, right_val)
                    else:
                        # It's an attribute of OBJ, CLASS, ...
                        export(left_id, right_val)

                rv = right_val

            rv = self.maybe_resolve_id(rv)
            iprint(f'Parsed expr: {" ".join(self.tokens[start:self.i])} which equals {rv}')
            return rv


    def expr_level2(self):
        """
        Resolves comparators
        """
        start = self.i
        rv = self.expr_level3()

        if self.current_token and self.current_token.startswith('COMP'):
            left_val = self.maybe_resolve_id(rv)
            comp = self.current_token
            self.advance() # eat the comp token
            right_val = self.maybe_resolve_id(self.expr_level3())
            ops = {
                'COMP==' : lambda x, y: x==y,
                'COMP<=' : lambda x, y: x<=y,
                'COMP>=' : lambda x, y: x>=y,
                'COMP<' : lambda x, y: x<y,
                'COMP>' : lambda x, y: x>y,
                'COMP!=' : lambda x, y: x!=y,
                }
            rv = 'INT1' if ops[comp](left_val, right_val) else 'INT0'
            iprint(f'Compared {left_val} {comp} {right_val}; result: {rv}')

        iprint(f'Parsed expr_level2: {" ".join(self.tokens[start:self.i])}')    
        return rv


    def expr_level3(self):
        """
        Resolves + and -
        """
        start = self.i
        rv = self.term()

        if self.maybe_eat('PNC+'):
            iprint('Detected + sign, starting next expr')
            rv = self.add(rv, self.term())

        iprint(f'Parsed expr_level3: {" ".join(self.tokens[start:self.i])}')    
        return rv


    def term(self):
        """
        Resolves * and /
        """
        start = self.i
        rv = self.factor()
        iprint(f'Parsed term: {" ".join(self.tokens[start:self.i])}')
        return rv

    def factor(self):
        start = self.i
        if self.maybe_eat('PNC('):
            rv = self.expr()
            self.eat_separators()
            self.eat('PNC)')
        else:
            rv = self.composed()
        iprint(f'Parsed factor: {" ".join(self.tokens[start:self.i])}')
        return rv

    # HIER VERDER
    # cat.printc() probeert eerst printc() te doen, en daarna cat.

    # 


    def composed(self):
        """Composed: ids/builtins before application of operators (), [], ."""
        # We're now expecting a variable, an id, builtin, list, etc.
        if self.maybe_eat('PNC['):
            # We've encountered a list
            rv = self.composed_list()
        else:
            rv = self.composed_id()
        return rv


    def composed_id(self):
        start = self.i
        rv = self.id()
        
        # The id/builtin can be operated on:
        while True:
            if self.maybe_eat('PNC.'):
                # Dot operator: get attribute
                old_rv = rv
                rv = self.maybe_resolve_id(rv)
                rv += self.id() # Part behind the dot can't be another list
                iprint(f'Detected getattr; rv {old_rv} -> {rv}')
            elif self.maybe_eat('PNC('):
                # Call operator, id must be a function
                iprint(f'Detected callable {rv}; building input arguments')
                input_args = []
                self.eat_separators()
                if self.maybe_eat('PNC)'):
                    # No input arguments given
                    pass
                else:
                    while True:
                        self.eat_separators()
                        input_args.append(self.expr())
                        iprint(f'Built args so far: {input_args}')
                        self.eat_separators()
                        if self.maybe_eat('PNC)'):
                            iprint(f'End of input arguments: {input_args}')
                            break
                        elif self.maybe_eat('PNC,'):
                            continue
                        else:
                            raise Exception(f'Expected ) or , but got {self.current_token}')

                # If the ID points to a class, the () is meant to instantiate:
                if LOCALS.get(rv, '').startswith('CLASS'):
                    rv = self.instantiate(rv, input_args)
                else:
                    rv = self.call(rv, input_args)
            else:
                break

        iprint(f'Parsed composed_id: {" ".join(self.tokens[start:self.i])}')
        return rv


    def composed_list(self):
        start = self.i
        rv = self.list()


        # The list can be operated on:
        if self.maybe_eat('PNC.'):
            # Dot operator: get attribute
            rv = self.maybe_resolve_id(rv)
            rv += '_' + self.composed_id() # Part behind the dot can't be another list

        # Operator [] now would be a getitem - TODO
        # Operator () is an error, a list can't be called

        iprint(f'Parsed composed_list: {" ".join(self.tokens[start:self.i])}')
        return rv



    def list(self):
        with indented_print('Starting new list'):
            list_mem_key = f'LIST{self.open_mem_slot}'
            self.open_mem_slot += 1

            self.mem[list_mem_key] = []

            self.eat_separators()
            if self.maybe_eat('PNC]'):
                # Empty list
                pass
            else:
                while True:
                    self.eat_separators()
                    # Don't allow assignments inside list
                    next_element = self.expr_level2()
                    if next_element.startswith('ID') and next_element not in self.mem:
                        raise Exception(f'{next_element} not defined!')
                    self.mem[list_mem_key].append(self.maybe_resolve_id(next_element))
                    self.eat_separators()
                    if self.maybe_eat('PNC,'):
                        continue
                    elif self.maybe_eat('PNC]'):
                        break
                    else:
                        raise Exception(f'Expected , or ] but got {self.current_token}')

            self.mem[list_mem_key + '_LEN'] = len(self.mem[list_mem_key])
            self.mem[list_mem_key] = self.mem[list_mem_key]
            return list_mem_key


    def id(self):
        if not(self.current_token.startswith('ID') or self.current_token.startswith('INT')):
            raise Exception(f'Expected identifier or base type, got {self.current_token}')
        rv = self.current_token
        self.advance()
        iprint(f'Parsed id: {rv}')
        return rv



    def resolve_id(self, id):
        if id.startswith('INT'):
            return id
        elif id in LOCALS:
            return LOCALS[id]
        elif id in GLOBALS:
            return GLOBALS[id]
        else:
            raise Undefined(f'Undefined id {id}')


    def maybe_resolve_id(self, id):
        if id.startswith('ID'):
            return self.resolve_id(id)
        return id

    def add(self, left, right):
        # Resolve IDs
        v_left = self.resolve_id(left)
        v_right = self.resolve_id(right)
        iprint(f'Adding {left}={v_left} + {right}={v_right}')
        if v_left.startswith('INT') and v_right.startswith('INT'):
            return 'INT' + str(int(v_left[3:]) + int(v_right[3:]))
        else:
            raise Exception(f'Don\'t know how to add {v_left} + {v_right}')


    def deffn(self):
        fn_id = self.id()
        with indented_print(f'Defining function {fn_id}') as msg:
            self.eat_separators()
            self.eat('PNC(')
            self.eat_separators()

            args = []

            if self.maybe_eat('PNC)'):
                # Function takes no arguments
                pass
            else:
                while True:
                    self.eat_separators()
                    args.append(self.id())
                    self.eat_separators()
                    if self.maybe_eat('PNC,'):
                        continue
                    elif self.maybe_eat('PNC)'):
                        break
                    else:
                        raise Exception('Expected ) or ,')


            self.eat_separators()
            fn_code_block = self.read_braces_block()

            fn_obj = new_obj()
            export(fn_obj, 'FN')
            export(fn_obj + 'ID__args__', ' '.join(args))
            export(fn_obj + 'ID__tokens__', ' '.join(fn_code_block))
            export(fn_obj + 'ID__name__', fn_id[2:])

            if self.inside_class_def and fn_id.startswith('ID'):
                class_var = self.class_nr + fn_id
                if class_var in LOCALS:
                    # If there already is a defined class_var, use it
                    export(class_var, fn_obj)
                elif fn_id in LOCALS:
                    # If no class_var exists but a local one does, use the local
                    local(fn_id, fn_obj)
                else:
                    # If neither exists, assume we mean a class_var
                    export(class_var, fn_obj)
            else:
                local(fn_id, fn_obj)

        return 'NULL'


    def call(self, fn_id, args):
        iprint(f'Called fn {fn_id} with args {args}')

        if fn_id == 'IDprint':
            print(f'POPOUT: {" ".join([self.resolve_id(a) for a in args])}')
            return 'NULL'

        if fn_id.startswith('ID'):
            fn_obj = LOCALS[fn_id]
        else:
            # The fn_id is an object or class attribute/method

            if fn_id.startswith('OBJ') and fn_id not in GLOBALS:
                # No OBJ method was found, so resolve it to a class method
                old_fn_id = fn_id
                obj_nr, id = fn_id.split('ID',1)
                class_nr = GLOBALS[obj_nr]
                fn_id = f'{class_nr}ID{id}'
                iprint(
                    f'No function {old_fn_id}; transcending to class method {fn_id},'
                    f' and using obj {obj_nr} as first input argument'
                    )
                args.insert(0, obj_nr)
            fn_obj = GLOBALS[fn_id]

        fn_arg_ids = GLOBALS[fn_obj+'ID__args__'].split()
        assert len(args) == len(fn_arg_ids)

        fn_code = GLOBALS[fn_obj+'ID__tokens__'].split()
        with subscope():
            # Set the input arguments to the function in the local scope
            for arg_id, val in zip(fn_arg_ids, args):
                local(arg_id, self.maybe_resolve_id(val))
            try:
                return parse(fn_code, inside_fn=True, subscope=False)
            except:
                print(
                    f'Failure in subparser during function call;'
                    f'  LOCALS: {pprint.pformat(LOCALS)}\n'
                    f'  GLOBALS: {pprint.pformat(GLOBALS)}\n'
                    )
                raise


    def instantiate(self, class_id, args):
        class_nr = LOCALS[class_id]
        obj = new_obj()
        export(obj, class_nr)

        init_method = class_nr + 'ID__init__'
        if init_method in GLOBALS:
            self.call(init_method, [obj] + args)
        elif len(args):
            raise Exception(f'Class {class_id[2:]} does not expect input args')

        return obj


    def get_attribute(self, obj, id):
        obj = self.maybe_resolve_id(obj)
        return obj + id



# expr: expr
# expr: expr '=' expr
# 
# expr: term ( ('+'|'-') term )*
# term: factor ( ('*'|'/') factor) )*
# factor: '(' expr ')' | composed
# composed: id_resolve_calls ('.' id_resolve_calls)*
# id_resolve_calls: callable | id
# callable: id '(' ')'   |   id '(' expr (',' expr)*   ')' 
#  
# fndef: 'def' id '(' (id ',')* ')' '{' ** '}'


# a = fn(b)
# expr = expr
# id = expr
# id = id ()


# cat.paws[1+1].claw_sharpness = 3+3
# cat.paws.getitem(1+1).claw_sharpness = 3+3


# factor: '(' expr ')' | single_var
# single_var: list_wops | id_wops
# id_wops: id | id '()'




# ((a*2) + b)*2
# get_cat().printc()

# met compleet gelijkwaardige ops gaat het mis:
# a+2 - b+2
# doet rv=b+2 -> rv=2-rv -> rv=a+rv

# met * voor + gaat het ook mis:
# a*2 + b*2
# doet left=a*2 -> right=b*2 -> rv = left+right

# Maar in het geval van get_cat().printc() kan b*2 (i.e. .printc())
# pas uitgevoerd worden als get_cat().printc resolved is, i.e. de +

# De operatie orde moet als volgt zijn:
# ((a*2) + b)*2
# get_cat().printc()

# Met een while loop?
# a*2 + b*2
# doet rv=a -> rv=a*2 -> rv=rv+b -> rv=rv*2
# Jup!



test_cases = [
    # 0
    """
a=3+5
b=a+2
c=a+b
a=a+b
""",
    # 1
    """
def myfunc(a){
    a = a + 2
    return a
    }
b = 6
print(b)
print(myfunc(myfunc(b)))
""",
    # 2
    """
a = 8
if a == 4 {
    a = 3
    }
elif a == 3 {
    a = 5
    }
else {
    a = 6
    }
print(a)
""",
    # 3
    """
a = [0 , 1+3, [7]]
print(a)
b = a
""",
    # 4
    """
def fn(a){
    if a < 4 { return fn(a+1) }
    else { return a }
    }
fn(1)
""",
    # 5
    """
a = 4
def fn(){ a = a + 1 }
fn()
a
""",
    # 6
    """
class Animal {
    a = 5
    def __init__(self, b){
        self.b = b
        }

    def printc(self){
        print(self.c)
        }
    }
cat = Animal(6)
cat.b
cat.c = 5
cat.printc()
""",
# 7
    """
class A {
    def __init__(self){
        self.a = 1
        }
    }

def incr(inst){
    inst.a = inst.a + 1
    }

a = A()
b = A()

incr(a)
incr(a)
incr(b)
print(a.a)
print(b.a)
"""
    ]

# VERDER:
# self.b assignment faalt al als self.b geresolved wordt, want bestaat natuurlijk niet
# voor assignments moet de resolvement uitgesteld worden...


def main():
    import argparse
    cli_parser = argparse.ArgumentParser()
    cli_parser.add_argument('thing', type=int, nargs='*', default=[-1])
    args = cli_parser.parse_args()

    if args.thing[0] == -1: args.thing = list(range(len(test_cases)))


    for index in args.thing:
        code = test_cases[index]
        print('-'*30 + f'\nRUNNING THE FOLLOWING CODE:\n{code}\n' + '-'*30)

        try:
            parse(tokenize(code))
        except Exception:
            print(f'FAILURE ON INDEX {index}; CODE:\n{code}')
            raise
        finally:
            print(f'LOCALS:\n{pprint.pformat(LOCALS)}')
            print(f'GLOBALS:\n{pprint.pformat(GLOBALS)}')



if __name__ == '__main__':
    main()