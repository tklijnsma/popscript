# pop: Programming on POSIX

`pop` (programming on POSIX) is a general-purpose object-oriented scripting language designed to work with nothing but POSIX builtins. It has a lexer and recursive descent parser with no dependencies or requirements other than a POSIX shell.


## Installation

To install `pop` in your current shell only:

```bash
source /dev/stdin <<< "$(curl -s https://raw.githubusercontent.com/tklijnsma/popscript/main/pop.sh)"
```

Test your installation:

```bash
pop -c 'print("Hello World!")'
Hello World!
```


## Overview of syntax

`pop` has a simple, Python-inspired syntax. It has a few basic types:

```python
a = 1  # a is an integer
a = 1.  # a is a float
a = "foo"  # a is a string
a = [ 1, "bar" ]  # a is a list
```

You can define functions:

```python
def my_function(a){
    a = a + 1
    print(a)
    }

my_function(2)
>>> 3
```

and classes:

```python
class Animal {
    def __init__(self, sound){
        self.sound = sound
        }

    def make_sound(self){
        print(self.sound)
        }
    }

cat = Animal("meow")
cat.make_sound()
>>> meow
```

Classes have Python-like dunder methods:

```python
class Cat{
    def __init__(self, name, claw_length){
        self.name = name
        self.claw_length = claw_length
        }
    
    def __lt__(self, other){
        return self.claw_length < other.claw_length
        }

    def __repr__(self){ return "kitty " + self.name }
    }

lenny = Cat("Lenny", 10)
bobby = Cat("Bobby", 20)
if lenny < bobby { winner = bobby } else { winner = lenny}
print(f"The winner is {winner}")
>>> The winner is kitty Bobby
```


`pop` can do if-statements, for-loops, and while-loops:

```python
a=4
if a < 3 { print("a is less than 3") }
else { print("a is equal to or greater than 3") }
>>> a is equal to or greater than 3
```

```python
for a in range(3){
    print(a)
    }
>>> 0
>>> 1
>>> 2
```

```python
a = 0
while a < 4 {
    print(a)
    a = a + 1
    }
>>> 0
>>> 1
>>> 2
>>> 3
```

Because `pop` consists of nothing but shell commands under the hood, interop with the shell is easy:

```python
a = shell("echo 'Hello' | sed 's#e#a#g'")
print(a)
>>> Hallo
```

Try a demo:

```bash
$ wget https://raw.githubusercontent.com/tklijnsma/popscript/main/demos/fizzbuzz_oop.pop
$ pop fizzbuzz_oop.pop
1
2
fizz!
4
buzz!
fizz!
7
8
fizz!
buzz!
11
fizz!
13
14
fizzbuzz!
16
17
fizz!
19
buzz!
```

## Why

I started working on `pop` out of annoyance with shell scripting. Have you ever wrote a shell script that calls an API, pipes the output to `tr` to replace comma's with line breaks or what have you, then _that_ is piped `sed` to remove trailing whitespace, which is piped to a hard-to-read `awk` command, which is piped to ...?

You inevitably run into gotcha's concerning whitespace. And the POSIX builtins, while powerful and performant, are just _awkward_ to use, unless you use these tools every day (which I don't).

If you're writing a one-off script, Python is great. Just do all your string manipulation in there, and use `subprocess`. Or find a Python interface for the tool you're using.

But if you're trying to write something reusable, perhaps a tool that is supposed to work on many platforms and regardless of what Python virtual environment you're in, writing your script in Python limits your portability. You can setup an isolated Python virtual environment every time you install your tool, and then update your `.bashrc` so you can call the script easily, but that's kind of a hassle and it has its own gotcha's.

The idea of `pop` is to be a general-purpose scripting language that is extremely easy to install: Just source `pop.sh` and run your script. Its aim is to be much easier to write and read than shell scripts, like Python, but avoid the pain of setting up Python environments.

Also, I read a blog post about recursive descent parsers and I wanted to try something like that. I learned a lot during the development of `pop`.


## Status

`pop` is slow. Extremely slow. The fizzbuzz-demo above takes about 40 seconds. While I anticipated performance would be an issue, in the current state I unfortunately have to conclude that the development of `pop` was probably an academic exercise.

A non-complete list of other things about the language that I didn't get around to implement:

- more string methods (\_\_eq__, \_\_getitem__, split, join, replace)
- a REPL
- an import system
- mechanism for escape chars in str, at least \~, \"
- global keyword
- minimal test suite
- more list methods (\_\_eq__, append, extend, slice)
- booleans
- single quote strings
- basic benchmarking
- += and the like
- dictionaries
- much better error messages
- delete keyword
- interpreter without any debug statements
- test on different shells (currently only tested in Bash)
- bitwise ops
- multiline strings
- garbage collection
- error handling
- array slicing
- source code minimization
- unpacking tuples for return, for loops, ...
- keyword arguments
- inheritance
- type(...) function
