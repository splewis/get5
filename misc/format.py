#!/usr/bin/python3

import os
import subprocess


replacements = {
    '\npublic\n' : '\npublic ',
    'any : ...' : 'any:...',
    '% 1' : '%1',
}


def main():
    root_path, _ = os.path.split(os.path.dirname(os.path.realpath(__file__)))
    scripting_path = os.path.join(root_path, 'scripting')
    files = []
    for (dirpath, dirnames, filenames) in os.walk(scripting_path):
        for f in filenames:
            if '.inc' in f or '.sp' in f:
                files.append(os.path.join(dirpath, f))

    for filename in files:
        subprocess.call('clang-format-3.9 -i {}'.format(filename), shell=True)
        with open(filename, 'r+') as f:
            data = f.read()
            for (k, v) in replacements.items():
                data = data.replace(k, v)

            # Trick of a hack so the 1st line of files also don't split
            # public onto a single line. The normal replacement doesn't work
            # since it assumes a blank line in front of it.
            if data.startswith('public\n'):
                data = data.replace('public\n', 'public ', 1)

            f.seek(0)
            f.write(data)
            f.truncate()


main()
