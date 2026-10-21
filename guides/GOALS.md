# SatnaOS Engineering Goals & Phase Tracker

## Project Mission
Build a robust 32-bit, multitasking x86 operating system and kernel from first principles, progressing from a bare-metal real-mode boot sector to protected mode, memory paging, dynamic heap, process scheduling, a FAT16 filesystem, ELF program execution, and an interactive shell.

---

## Current Status
- **Current Phase:** Phase 2 Complete (Real-Mode Bootloader) / Advancing to Phase 3 (Disk I/O)
- **Last Updated:** 2026-10-21
- **Current Working Directory:** `SatnaOS/`
- **Next Milestone:** Implement multi-sector disk reading via BIOS `INT 0x13` and verify disk buffers in RAM.

---

## Engineering Milestones Checklist

- [x] **Phase 1: Environment & Tool Verification**
  - [x] Assembler: NASM 2.16.01 installed and verified.
  - [x] Emulator: QEMU 8.2.2 (`qemu-system-i386`, `qemu-system-x86_64`) installed and verified.
  - [ ] Cross-compiler: `i686-elf-gcc` and `i686-elf-ld` (required for C kernel compilation).
  - [ ] Debugger: GDB configured for remote QEMU stub debugging (`-s -S`).
- [x] **Phase 2: Real-Mode Boot Sector**
  - [x] 16-bit real-mode entry point at origin `0x7C00`.
  - [x] BIOS teletype video output via `INT 0x10` (`AH = 0x0E`).
  - [x] String traversal with `lodsb`, null-byte termination, and loop branch.
  - [x] Sector padding (`times 510 - ($ - $$) db 0`) and MBR magic signature `0xAA55`.
  - [x] Boot verification in QEMU with "Hello, World!" output.
- [ ] **Phase 3: Disk Loading & Real-Mode Interrupts**
  - [ ] Load consecutive sectors from disk to RAM using BIOS `INT 0x13`.
  - [ ] LBA-to-CHS addressing calculation and error handling (Carry Flag inspection).
- [ ] **Phase 4: 32-Bit Protected Mode Switch**
  - [ ] Enable A20 line.
  - [ ] Define and load Global Descriptor Table (GDT).
  - [ ] Set Protection Enable (PE) bit in `CR0` and perform far jump to flush pipeline.
- [ ] **Phase 5: Interrupts, Paging & Heap Memory**
  - [ ] Protected mode Interrupt Descriptor Table (IDT) and 8259 PIC remapping.
  - [ ] Two-level 4KB paging (Page Directory and Page Tables) with `CR3`.
  - [ ] Dynamic kernel memory allocator (`kmalloc` / `kfree`).
- [ ] **Phase 6: Tasks, Processes & Multitasking**
  - [ ] Hardware Task State Segment (TSS) and Ring 0 stack switching.
  - [ ] Process Control Blocks (PCB) and context switching routines (`pushad`/`popad`).
  - [ ] PIT timer tick (IRQ0) preemptive round-robin scheduler.
- [ ] **Phase 7: Virtual File System, FAT16 & ELF Loader**
  - [ ] VFS abstraction layer and ATA disk driver (PIO mode).
  - [ ] FAT16 filesystem parsing (BPB, FAT tables, root directory, clusters).
  - [ ] 32-bit ELF parser, memory loader, and Ring 3 user mode jump (`iret`).
- [ ] **Phase 8: Keyboard Driver & Interactive Shell**
  - [ ] PS/2 keyboard controller driver (port `0x60`, IRQ1) with circular key buffer.
  - [ ] VGA text console driver with hardware cursor and scrolling support.
  - [ ] Interactive command line interpreter (`help`, `ls`, `run`, `clear`).

---

## Toolchain & System Record

| Tool / Dependency | Version Detected | Status | Purpose |
| :--- | :--- | :--- | :--- |
| **OS Platform** | Linux (x86_64) | Active | Host development environment |
| **NASM** | 2.16.01 | Verified | Assembling x86 real-mode and protected-mode assembly |
| **QEMU (i386)** | 8.2.2 | Verified | 32-bit x86 system emulator for target platform execution |
| **QEMU (x86_64)** | 8.2.2 | Verified | 64-bit x86 emulator backwards-compatible with 16/32-bit |
| **Cross-Compiler** | `i686-elf-gcc` | Upcoming | Required for freestanding C kernel compilation without host OS pollution |

---

## Project File Inventory

```
/home/praveen/Documents/vs/kernel/
├── .gitignore               # Excludes build artifacts, internal agents, and roadmap
├── README.md                # Public GitHub project showcase & quickstart
├── guides/
│   ├── GOALS.md             # Operational phase tracker & milestone log (this file)
│   ├── KERNEL_GUIDE.md      # Deep technical architecture reference & knowledge base
│   ├── ASSEMBLY_GUIDE.md    # x86 assembly for C++ engineers
│   └── SETUP_GUIDE.md       # Toolchain, build, and debugging documentation
└── SatnaOS/
    ├── boot.asm             # 16-bit real-mode boot sector source code (origin 0x7c00)
    └── boot.bin             # Assembled 512-byte raw MBR binary (ignored by git)
```

---

## Detailed Milestone Log

### Milestone: Phase 2 Real-Mode Bootloader Verified
- **Date Completed:** 2026-10-20
- **Files Involved:** `SatnaOS/boot.asm`, `SatnaOS/boot.bin`
- **Technical Validation:**
  - Assembled flat 512-byte binary using `nasm -f bin boot.asm -o boot.bin`.
  - Verified exact 512-byte sector boundary ending with `0x55 0xAA` little-endian signature.
  - Executed in QEMU via `qemu-system-i386 -drive format=raw,file=boot.bin`.
  - Verified BIOS `INT 0x10` (`AH=0x0E`) teletype rendering of "Hello, World!".

