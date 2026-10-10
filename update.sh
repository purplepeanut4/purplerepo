#!/bin/sh
# Run this in the repo folder after adding or updating a .deb (Mac/Linux/WSL).
dpkg-scanpackages -m . /dev/null | sed 's#^Filename: \./#Filename: #' > Packages
bzip2 -k -f Packages
gzip -k -f Packages
echo "Done. Upload Packages, Packages.bz2, Packages.gz and the new .deb to GitHub."
