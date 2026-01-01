echo "WARNING: This script should only be run once."
read -p "Press enter to continue, or close this terminal (ctrl+c)." dummy

echo "export PATH=\$PATH:$PWD" >> ~/.zshrc
echo "lua-scripts has been added to your \$PATH."
echo ""
echo "Due to a bug, I can't make THIS terminal update its path."
echo "Run \"source ~/.zshrc\" next or start a new terminal."
