# SatnaOS Toolchain, Build & Debugging Environment Guide

> **Operational Engineering Reference for Host Setup, QEMU Emulation & Cross-Compilation**

---

## Navigation & Quick Reference
- [1. Development Toolchain Overview](#1-development-toolchain-overview) *(Line ~16)*
- [2. NASM Assembly & Binary Formats](#2-nasm-assembly--binary-formats) *(Line ~45)*
- [3. QEMU Hardware Emulation & Execution Commands](#3-qemu-hardware-emulation--execution-commands) *(Line ~85)*
- [4. Advanced Debugging: GDB & QEMU Monitor](#4-advanced-debugging-gdb--qemu-monitor) *(Line ~140)*
- [5. Diagnosing Triple Faults & System Crashes](#5-diagnosing-triple-faults--system-crashes) *(Line ~185)*
- [6. The Freestanding Cross-Compiler (`i686-elf-gcc`)](#6-the-freestanding-cross-compiler-i686-elf-gcc) *(Line ~220)*

---

## 1. Development Toolchain Overview

The SatnaOS build pipeline operates strictly in a **freestanding environment** (no host C standard library, no host dynamic linkers). The primary tools and roles are:

```
[boot.asm (Source)] ---> [NASM Assembler] ---> [boot.bin (Raw Disk Image)]
                                                        |
                                                        v
                                             [QEMU System Emulator] <---> [GDB Remote Debugger]
```

### Verified Host Environment
- **Host OS:** Linux (x86_64)
- **Assembler:** NASM 2.16.01 (`/usr/bin/nasm`)
- **Target Emulator:** QEMU 8.2.2 (`/usr/bin/qemu-system-i386`)

---

## 2. NASM Assembly & Binary Formats

### Generating Raw Boot Sectors
```bash
cd SatnaOS
nasm -f bin boot.asm -o boot.bin
```

#### Flag Explanation
- `-f bin`: Instructs NASM to emit a **pure flat binary**.
  - Unlike object files (`.o`, `.elf`), a flat binary has **zero headers, zero symbol tables, and zero metadata**.
  - The first byte of the file is the exact first instruction or byte executed at memory origin `0x7C00`.
- `-o boot.bin`: Output filename.

### Verifying Image Size
A standard Master Boot Record (MBR) sector must be **exactly 512 bytes**:
```bash
ls -la boot.bin
# Output must show: 512 bytes
```

### Inspecting Raw Machine Bytes
To inspect the generated opcodes:
```bash
hexdump -C boot.bin
# Or view with objdump:
ndisasm -b 16 boot.bin
```

---

## 3. QEMU Hardware Emulation & Execution Commands

### Primary Execution Command (Recommended)
```bash
qemu-system-i386 -drive format=raw,file=boot.bin
```

#### Why This Syntax?
- `qemu-system-i386`: Target emulator specifically configured for 32-bit x86 architecture.
- `-drive format=raw,file=boot.bin`: Modern, explicit syntax that instructs QEMU:
  1. Do not auto-probe disk formats (avoids security warnings).
  2. Treat `boot.bin` as a raw sector-by-sector disk.
  3. Load sector 0 into memory at `0x0000:0x7C00` via SeaBIOS.

### Legacy Syntax Comparison
```bash
qemu-system-x86_64 -hda ./boot.bin
```
- `-hda`: Attaches `boot.bin` as primary IDE master drive. Requires format probing.
- `x86_64`: Emulates a 64-bit CPU. While backward-compatible with 16-bit real mode, using `i386` is preferred to match our 32-bit target kernel architecture.

### Useful QEMU Flags
| Flag | Purpose |
| :--- | :--- |
| `-curses` | Runs QEMU text interface directly inside your terminal (useful over SSH or without X11). |
| `-nographic` | Disables graphical window; redirects serial port to terminal stdio. |
| `-s -S` | Pauses CPU at boot and opens GDB server on `localhost:1234`. |
| `-d int,cpu_reset` | Logs every interrupt and CPU reset directly to console or logfile. |

---

## 4. Advanced Debugging: GDB & QEMU Monitor

### Remote Debugging with GDB
To pause execution at the very first instruction at `0x7C00`:

1. **Launch QEMU with GDB stub enabled:**
   ```bash
   qemu-system-i386 -drive format=raw,file=boot.bin -s -S
   ```
   *(QEMU will freeze immediately waiting for debugger connection).*

2. **In a second terminal, launch GDB:**
   ```bash
   gdb
   ```

3. **Connect to QEMU:**
   ```gdb
   target remote localhost:1234
   set architecture i8086
   break *0x7c00
   continue
   ```

4. **Useful GDB Commands for Real Mode:**
   - `info registers`: Dumps `EAX`, `EBX`, `ECX`, `EDX`, `ESP`, `EBP`, `ESI`, `EDI`, `EIP`, `EFLAGS`.
   - `x/16xb 0x7c00`: Inspects 16 bytes of memory at `0x7C00` in hex.
   - `stepi` (or `si`): Executes exactly one assembly instruction.

### The QEMU Monitor Interface
While QEMU is running, press **`Ctrl + Alt + 2`** to toggle into the internal QEMU monitor:
- `info registers`: Displays all CPU hardware register values.
- `info mem`: Displays active virtual memory mappings (once paging is enabled).
- `xp /16xb 0x7c00`: Inspects physical memory directly inside QEMU.
- Press **`Ctrl + Alt + 1`** to toggle back to the display screen.

---

## 5. Diagnosing Triple Faults & System Crashes

In bare-metal systems, an unhandled exception (e.g. division by zero, invalid segment selector, or bad page table) triggers a Double Fault (`#DF`, interrupt `0x08`). If the double fault handler itself faults, the CPU enters a **Triple Fault** and triggers an immediate hardware reset.

To catch the exact register state during a crash:
```bash
qemu-system-i386 -drive format=raw,file=boot.bin -d int,cpu_reset -D qemu.log
```
Inspect `qemu.log` to view the exact Instruction Pointer (`EIP`) and CPU register state at the moment of failure.

---

## 6. The Freestanding Cross-Compiler (`i686-elf-gcc`)

When we reach the 32-bit Protected Mode kernel in Phase 4 and 5, we transition from pure assembly into C.

### Why Host GCC Cannot Be Used
- Host GCC targets Linux ABI (ELF with dynamic linking, glibc dependencies, and POSIX assumptions).
- Compiling bare-metal code with host GCC leads to undefined symbols (`_start`, `__libc_start_main`) or accidental reliance on Linux system calls.

### Required Cross-Compiler
We will use a freestanding cross-compiler targeting **`i686-elf`**:
- Target: `i686-elf-gcc`
- Linker: `i686-elf-ld`
- Flags: `-ffreestanding -O2 -Wall -Wextra -fno-exceptions -fno-rtti`

