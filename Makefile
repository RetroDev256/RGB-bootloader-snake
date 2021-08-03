build:
	nasm -Ox bootloader.asm -o bootloader.bin
run:
	make build
	qemu-system-x86_64 -hdb bootloader.bin
clean:
	rm bootloader.bin
