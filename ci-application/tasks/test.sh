var1="pacman-ci-tr-2clp2"

echo $var1

var2=${var1:(${#var1} - 5):${#var1}}

var3="d413d9a549a3b7d27ec06af06c0e1ae05f9c5ec4"

echo $var3

var3=${var3:0:7}

echo $var3

tag=$var2-$var3

echo $tag