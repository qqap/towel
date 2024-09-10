echo "\n\n" >> spec

find initramfs -type f | while read -r file; do
    path=$(echo "$file" | sed 's|^initramfs/||')
    echo "file /$path $file 755 0 0" >> spec
done
