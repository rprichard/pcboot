pcboot
======

pcboot is a (hypothetical) BIOS-based boot menu and loader.

What is currently implemented:
 - A single-sector pcboot MBR loader that scans the current drive and
   chainloads the pcboot VBR.
 - A FAT32 boot volume, the first sector of which is the pcboot VBR, which
   scans the boot drive looking for itself.  When found, it loads "stage1"
   from the FAT32 reserved area.  (The FAT32 reserved area is 16KiB and
   contains the VBR, backup VBR, and FSInfo sector, leaving 14.5KiB for
   stage1.)
 - stage1 loads stage2 by reading the STAGE2.BIN file from the boot volume.

What remains:
 - stage2 should show a menu to the user.
 - Potentially, it allows editing the menu, but that requires *writing* to the
   FAT32 volume, not just reading it.
 - Actually booting an OS(!)

stage2 needs to actually implement boot protocols, somehow, which will be
somewhat awkward.  Does pcboot follow GRUB and have built-in knowledge of
all file systems and custom protocols?  I feel like that's violating some
kind of boundary.  Possibilities:

 - Perhaps it makes sense to use whichever protocol each OS is designed for:
    - Linux has a simple boot protocol.  We can require that the kernel/initfs
      be located in the FAT32 volume, so that pcboot can ignore the multitude
      of Linux filesystems.
    - Many OSs can be booted by chainloading a boot sector.
 - Perhaps implement the Multiboot spec?
 - Perhaps follow UEFI more closely and separate out boot protocol knowledge
   and/or FS knowledge into modules independent of pcboot, with a stable API?
   (Seems like a like of trouble...)


Prerequisites
-------------

To build:
 - GNU make
 - rustc
 - nasm
 - gold (the linker, Debian binutils package)
 - python2

For Rust, you need two things:
 - Nightly Rust binaries targetting 32-bit Linux
 - A Rust source tree of the same revision

Stable Rust builds do not work, at least because pcboot uses `#![no_std]`.
As of this writing, `rustc 1.4.0-nightly (cd138dc44 2015-09-02)` works.

To test:
 - mtools
 - sfdisk
 - qemu-system-x86_64 (Alternatively, bochs or VirtualBox.  See mk/test.sh)


Building and testing
--------------------

1. Edit the Makefile and change the `rustc` and `RUST_LIBCORE_SRC` variables to
   point to a `rustc` targeting 32-bit Linux and to the directory containing
   `libcore`'s source.

2. Run `make` to build.  The build artifacts are placed into the `build`
   subdirectory.

3. Run `make test` to test.


Licensing
---------

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
