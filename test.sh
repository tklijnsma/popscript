source pop.sh


basic=$(cat << EndOfMessage
a=3+5
print(a)
b=a+2
print(b)
c=a+b
print(c)
a=a+b
print(a)
EndOfMessage
)

func1=$(cat << EndOfMessage
def myfunc(a,b){
    a = a + 2
    return a
    }
b = 6
myfunc(b,0)
print(b)
print(myfunc(myfunc(b,0),0))
EndOfMessage
)

func2=$(cat << EndOfMessage
def fn(a){
    if a < 4 { return fn(a+1) }
    else { return a }
    }
print(fn(1))
EndOfMessage
)

func3=$(cat << EndOfMessage
a = 4
def fn(){ a = a + 1 }
fn()
print(a)
EndOfMessage
)

func4=$(cat << EndOfMessage
def my_function(a){
    a = a + 1
    print(a)
    }
my_function(2)
EndOfMessage
)


if1=$(cat << EndOfMessage
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

list1=$(cat << EndOfMessage
a = [0 , 1+3, [7]]
print(a)
b = a
print(b[2])
print(b[2][0])
EndOfMessage
)

list2=$(cat << EndOfMessage
my_list = [4, 1, -3.4, 10, 9, 8]
max_val = -1000000
for val in my_list {
    if val > max_val { max_val = val }
    }
print(max_val)
EndOfMessage
)

list3=$(cat << EndOfMessage
a=[5,3]
print(a[0])
print(a[1])
print(a.length())
print([].length())
# These should produce index errors:
# print(a[2])
# print([][0])
EndOfMessage
)

class1=$(cat << EndOfMessage
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

class2=$(cat << EndOfMessage
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


class3=$(cat << EndOfMessage
class A { def __repr__(self){return 3} }
class B { def __repr__(self){return "I am a class!"} }
class C {}
class D { def __repr__(self){return B()} }
a = A()
b = B()
c = C()
d = D()
print(a)
print(b)
print(c)
print(d)
EndOfMessage
)


class4=$(cat << EndOfMessage
class A {
    def __init__(self, val){
        self.val = val
        }
    def __add__(self, o){
        return A(o.val + self.val)
        }
    }
a = A(2)
b = A(3)
c = a+b
print(c.val)
EndOfMessage
)


class5=$(cat << EndOfMessage
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
EndOfMessage
)


if2=$(cat << EndOfMessage
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

if3=$(cat << EndOfMessage
if 0 {def fn(){ print(4) }} else {def fn(){ print(5) }}
fn()
EndOfMessage
)

if4=$(cat << EndOfMessage
a=4
if 1 {
    if a == 9 { b = 8 }
    else { b = 9 }
    }
else { c = 2 }
print(b)
EndOfMessage
)

if5=$(cat << EndOfMessage
a=4
if a < 3 { print("a is less than 3") }
else { print("a is equal to or greater than 3") }
EndOfMessage
)


comp1=$(cat << EndOfMessage
1 == 1
1 == 2
1 <= 2
EndOfMessage
)

str1=$(cat << EndOfMessage
a="Okay"
b="Hello World!"
print(a.length())
print(b.length())
print(a)
print(b)
EndOfMessage
)


err1=$(cat << EndOfMessage
non_existing_fn(3)
EndOfMessage
)


str2=$(cat << EndOfMessage
a="begin "
b=" end"
c=a+b
print(c)
EndOfMessage
)


range1=$(cat << EndOfMessage
a=range(5)
print(a[2])
EndOfMessage
)

for1=$(cat << EndOfMessage
for a in range(3){
    print(a)
    }
EndOfMessage
)

for2=$(cat << EndOfMessage
for a in range(2){
    for b in range(2){
        if a + b == 2 {
            print("buzz!")
            }
        }
    }
EndOfMessage
)


for3=$(cat << EndOfMessage
for a in [5+3, 9, "hi"]{
    print(a)
    }
EndOfMessage
)


for4=$(cat << EndOfMessage
for a in range(4){
    if a < 2 { continue }
    print(a)
    }
EndOfMessage
)

while1=$(cat << EndOfMessage
a = 0
while a < 4 {
    print(a)
    a = a + 1
    }
EndOfMessage
)

while2=$(cat << EndOfMessage
a = 0
while a < 10 {
    while a < 5 {
        a = a + 1
        }
    print(a)
    a = a + 1
    }
EndOfMessage
)


while3=$(cat << EndOfMessage
a = 0
while a < 5 {
    a = a + 1
    if a < 3 { continue }
    print(a)
    }
EndOfMessage
)


forwhile1=$(cat << EndOfMessage
a = 0
while a < 10 {
    if a == 4 { break }
    for i in range(a) {
        print(i)
        }
    a = a + 1
    }
print("finished")
# 0 0 1 0 1 2
EndOfMessage
)


tokenize1=$(cat << EndOfMessage
a = -1 - 4
EndOfMessage
)


tokenize_floats=$(cat << EndOfMessage
a = 0.4 + 5 ;;
a = .4 + 5 ;;
a = 3. + 5 ;;
a = . + ;;
a3.method() ;;
EndOfMessage
)

tokenize_negfloats=$(cat << EndOfMessage
a = -0.4 + 5 ;;
a = -.4 + 5 ;;
a = -3. + 5 ;;
a = . + ;;
a3.method() ;;
EndOfMessage
)

negint1=$(cat << EndOfMessage
a = -1 + 4
print(a)
b = -1 + -4
print(b)
EndOfMessage
)


floats1=$(cat << EndOfMessage
a = .1
b = 4.5
print(a+b)
a = -.1
b = -5.5
print(a+b)
a = -.1
b = 5
print(a+b)
print(0.1 < 0.3)
print(0.3 > 0.3)
EndOfMessage
)



overloaded_comps=$(cat << EndOfMessage
class A {
    def __lt__(self, o){return 1}
    def __gt__(self, o){return 2}
    def __le__(self, o){return 3}
    def __ge__(self, o){return 4}
    def __eq__(self, o){return 5}
    def __ne__(self, o){return 6}
    }
a = A()
print(a<3)
print(a>3)
print(a<=3)
print(a>=3)
print(a==3)
print(a!=3)
EndOfMessage
)

binaryops=$(cat << EndOfMessage
print(5+3)
print(5-3)
print(5*3)
print(5/3)
print(2*2+3/2*2)
print(2*(2+3)/2*2)
EndOfMessage
)

overloaded_ops=$(cat << EndOfMessage
class A {
    def __add__(self, o){return 1}
    def __sub__(self, o){return 2}
    def __prod__(self, o){return 3}
    def __div__(self, o){return 4}
    }
a = A()
print(a+3)
print(a-3)
print(a*3)
print(a/3)
EndOfMessage
)

tokenize_fstrings=$(cat << EndOfMessage
a = 3
b = f"this is a test: {a}"
EndOfMessage
)

fstrings1=$(cat << EndOfMessage
a = 3
b = f"this is a test: {a}, bla"
EndOfMessage
)

fstrings2=$(cat << EndOfMessage
class A{ def __repr__(self){ return "I'm a class" } }
print(f"Class A's repr returns: {A()}; also, some braces: {{ }} }} {{")
EndOfMessage
)

string_conversion=$(cat << EndOfMessage
class A{ def __repr__(self){ return "I'm a class" } }
print(str(A()))
print(str(3) + str(4))
EndOfMessage
)

shell1=$(cat << EndOfMessage
a = shell("ls *.py")
print(a)
EndOfMessage
)

shell2=$(cat << EndOfMessage
a = shell("echo 'Hello' | sed 's#e#a#g'")
print(a)
EndOfMessage
)

shell3=$(cat << EndOfMessage
a = shell("echo 'Hello World!' > myfile.txt")
print(shell("cat myfile.txt"))
EndOfMessage
)

modulo_and_floordiv=$(cat << EndOfMessage
print(10 % 3)
print(10 // 3)
print(10 / 3)
print(11.2 % 3)
print(11.2 // 3.2)
print(11.2 // 3.9)
EndOfMessage
)

and1=$(cat << EndOfMessage
print(2 and 2)
print(2 and 0)
print(2 or 0)
print(0 or 0)
print(0 or 0 or 1)
print(1 and 1 and 1)
print(1 and 1 and 0)
EndOfMessage
)

overloading_demo=$(cat << EndOfMessage
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

lenny = Cat("Lenny", 10) ; bobby = Cat("Bobby", 20)
if lenny < bobby { winner = bobby } else { winner = lenny}
print(f"The winner is {winner}")
EndOfMessage
)


# _______________________________________________________________
# basic
# func1 func2 func3
# if1 if2 if3 if4
# list1 list2
# class1 class2 class3 class4
# comp1 overloaded_comps
# str1 str2
# range1
# for1 for2 for3 for4
# while1 while2 while3
# forwhile1
# negint1
# floats1
# err1
# tokenize1
# tokenize_floats
# tokenize_negfloats

main(){
    local code start_time end_time diff

    local scripts=()
    for arg in $@ ; do
        if streq "$arg" "-d" ; then
            debug_mode=1
        elif streq "$arg" "for" ; then
            scripts+=("for1" "for2" "for3" "for4")
        elif streq "$arg" "class" ; then
            scripts+=("class1" "class2" "class3" "class4")
        elif streq "$arg" "while" ; then
            scripts+=("while1" "while2" "while3")
        elif streq "$arg" "func" ; then
            scripts+=("func1" "func2" "func3")
        elif streq "$arg" "list" ; then
            scripts+=("list1" "list2")
        elif streq "$arg" "str" ; then
            scripts+=("str1" "str2")
        else
            scripts+=("$arg")
        fi
    done

    for arg in ${scripts[@]} ; do

        code="${!arg}"
        if test -z "$code" ; then
            echo "No such script: $arg"
            continue
        fi

        if streq "${arg:0:8}" "tokenize" ; then
            echo "_____________________________________________________________"
            echo "Tokenizing $arg; code:"
            echo "$code"
            echo "----"
            echo "$code" | tokenize
            continue
        fi

        echo "_____________________________________________________________"
        echo "Running $arg; code:"
        echo "$code"
        echo "----"
        start_time=$(date +%s)

        if ( run "$code" ) ; then
            end_time=$(date +%s)
            diff=$(echo "$end_time - $start_time" | bc)
            echo "---- Ran $arg succesfully, t=${diff}s"
        else
            echo "Error on $arg"
            if test $debug_mode -eq 0 ; then
                debug_mode=1
                run "$code"
            fi
            return 1
        fi
    done
    }

main $@