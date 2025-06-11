if echo "$PATH" | grep -q -E "(^|:)$current_dir(:|$)"; then
  echo "lua-scripts is already in your \$PATH."
else
  echo "export PATH=\$PATH:$PWD" >> ~/.bashrc
  sleep 1
  source ~/.bashrc
  echo "lua-scripts has been added to your \$PATH."
fi
