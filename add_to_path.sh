echo "WARNING: This script should only be run once."
read -p "Press enter to continue, or close this terminal (ctrl+c)." dummy

echo >> ~/.bashrc
echo "export PATH=\$PATH:$PWD" >> ~/.bashrc
echo "lua-scripts has been added to your \$PATH."
echo ""
echo "Due to a bug, I can't make THIS terminal update its path."
echo "Run \"source ~/.bashrc\" next or start a new terminal."
