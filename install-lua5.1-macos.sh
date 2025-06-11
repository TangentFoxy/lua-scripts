# this file exists because brew removed the ability to install lua 5.1
#   perhaps I should install luajit first instead?
wget https://www.lua.org/ftp/lua-5.1.5.tar.gz
tar xvzf lua-5.1.5.tar.gz
cd lua-5.1.5/src
make macosx
sudo cp lua /usr/local/bin/lua
