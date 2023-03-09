source parser.sh

code=""

if test "$1" = "1" || test -z "$1" ; then
code=$(cat << EndOfMessage
a=3+5
b=a+2
c=a+b
a=a+b
EndOfMessage
)
run "$code"
fi

if test "$1" = "2" || test -z "$1" ; then
code=$(cat << EndOfMessage
def myfunc(a,b){
    a = a + 2
    return a
    }
b = 6
myfunc(b,0)
# print(b)
# print(myfunc(myfunc(b,0),0))
EndOfMessage
)
run "$code"
fi

if test "$1" = "3" || test -z "$1" ; then
code=$(cat << EndOfMessage
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
EndOfMessage
)
run "$code"
fi

if test "$1" = "4" || test -z "$1" ; then
code=$(cat << EndOfMessage
a = [0 , 1+3, [7]]
print(a)
b = a
EndOfMessage
)
run "$code"
fi

if test "$1" = "5" || test -z "$1" ; then
code=$(cat << EndOfMessage
def fn(a){
    if a < 4 { return fn(a+1) }
    else { return a }
    }
fn(1)
EndOfMessage
)
run "$code"
fi

if test "$1" = "6" || test -z "$1" ; then
code=$(cat << EndOfMessage
a = 4
def fn(){ a = a + 1 }
fn()
a
EndOfMessage
)
run "$code"
fi

if test "$1" = "7" || test -z "$1" ; then
code=$(cat << EndOfMessage
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
EndOfMessage
)
run "$code"
fi

if test "$1" = "8" || test -z "$1" ; then
code=$(cat << EndOfMessage
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
EndOfMessage
)
run "$code"
fi


if test "$1" = "9" || test -z "$1" ; then
code=$(cat << EndOfMessage
a = 1
if a < 1 {
    a = 2
    }
elif a==1 {
    a = 3
    }
elif a>2 {
    a = 4
    }
else {
    a = 5
    }
print(a)
EndOfMessage
)
run "$code"
fi

if test "$1" = "10" || test -z "$1" ; then
code=$(cat << EndOfMessage
if 0 {def fn(){ print(4) }} else {def fn(){ print(5) }}
fn()
EndOfMessage
)
run "$code"
fi

if test "$1" = "11" || test -z "$1" ; then
code=$(cat << EndOfMessage
1 == 1
1 == 2
1 <= 2
EndOfMessage
)
run "$code"
fi

if test "$1" = "12" || test -z "$1" ; then
code=$(cat << EndOfMessage
a="Okay"
b="Hello World!"
print(a.length())
print(b.length())
print(a)
print(b)
EndOfMessage
)
run "$code"
fi


if test "$1" = "13" || test -z "$1" ; then
code=$(cat << EndOfMessage
a=[1,3]
print(a)
EndOfMessage
)
run "$code"
fi
