# RGB-bootloader-snake

  This program was originally conceived as a challenge for optimization, as well as a proof of concept for super small games, fitting inside only 512 bytes.

  To build the game, use the NASM compiler, with the -Ox flag (if not selected by default). The output file will be bootable, which means it can be flashed to disk, or opened with QEMU to boot it.

  To play the game:
    - Use the Arrow Keys
    - Don't run into your tail
    - Don't run into the wall
    - Follow a minimal hamiltonian path to win (just kidding - do what you will with this)
    - Enjoy, and possibly improve the game to your fit your custom desires

  The program was developed for mode 0x13, under an x86 PC. Source code and a release is included, where both are released under license.
