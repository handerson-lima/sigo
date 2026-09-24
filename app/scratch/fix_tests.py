import os
import glob
import re

test_files = glob.glob('test/**/*.dart', recursive=True)

for file in test_files:
    with open(file, 'r') as f:
        content = f.read()

    new_content = content
    new_content = new_content.replace("status: 'noPrazo'", "status: LoteStatus.noPrazo")
    
    if new_content != content:
        with open(file, 'w') as f:
            f.write(new_content)
        print(f"Fixed status in {file}")
