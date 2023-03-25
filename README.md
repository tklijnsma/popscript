# pop: Programming on POSIX

`pop` (programming on POSIX) is a general purpose object-oriented scripting language designed to work with nothing but POSIX builtins. It has no dependencies or requirements other than a POSIX shell.


## Installation

To install `pop` in your current shell only:

```bash
source /dev/stdin <<< "$(curl -s https://raw.githubusercontent.com/tklijnsma/popscript/main/pop.sh)"
```

Test your installation:

```bash
$ pop -c 'print("Hello World!")'
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

