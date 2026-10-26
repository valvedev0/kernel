# SatnaOS Engineering Goals & Phase Tracker

## Project Mission
Build a robust 32-bit, multitasking x86 operating system and kernel from first principles, progressing from a bare-metal real-mode boot sector to protected mode, memory paging, dynamic heap, process scheduling, a FAT16 filesystem, ELF program execution, and an interactive shell.

---

## Current Status
- **Current Phase:** Phase 3 Complete (Real-Mode Disk I/O & Secondary Sector Loading) / Advancing to Phase 4 (Protected Mode Switch)
- **Last Updated:** 2026-10-26
- **Current Working Directory:** `SatnaOS/`
- **Next Milestone:** Enter 32-bit Protected Mode: enable A20 gate, define GDT, set CR0 PE bit, and jump to 32-bit kernel code.

---

## Engineering Milestones Checklist

- [x] **Phase 1: Environment & Tool Verification**
  - [x] Assembler: NASM 2.16.01 installed and verified.
  - [x] Emulator: QEMU 8.2.2 (`qemu-system-i386`, `qemu-system-x86_64`) installed and verified.
  - [ ] Cross-compiler: `i686-elf-gcc` and `i686-elf-ld` (required for C kernel compilation).
  - [ ] Debugger: GDB configured for remote QEMU stub debugging (`-s -S`).
- [x] **Phase 2: Real-Mode Boot Sector & Architecture Normalization**
  - [x] 16-bit real-mode entry point and far jump (`jmp 0x7c0:start`) for `CS` segment normalization.
  - [x] Origin set to `0` with segment alignment (`DS = 0x07C0`, `ES = 0x07C0`).
  - [x] Safe downward hardware stack setup (`SS = 0x0000`, `SP = 0x7C00`) with atomic `cli`/`sti` protection.
  - [x] BIOS teletype video output via `INT 0x10` (`AH = 0x0E`).
  - [x] String traversal with `lodsb`, null-byte termination, and loop branch.
  - [x] Sector padding (`times 510 - ($ - $$) db 0`) and MBR magic signature `0xAA55`.
  - [x] Boot verification in QEMU with "Hello, World!" output.
- [x] **Phase 3: Multi-Sector Disk Loading & Early Filesystem Architecture**
  - [x] Filesystem BIOS Parameter Block (BPB) space reservation (`times 33 db 0`).
  - [x] Load Sector 2 from disk to RAM at `0x7E00` via BIOS `INT 0x13` (`AH = 0x02`, CHS mode).
  - [x] Hardware error handling via Carry Flag check (`jc error`).
  - [x] Build automation with `Makefile` and `dd` generating multi-sector disk images.
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
├── portfolio_export/        # Git-ignored local staging area for portfolio website
│   └── index.html           # Full-featured research page ready to paste into portfolio
└── SatnaOS/
    ├── Makefile             # Build automation assembling boot sector & stitching multi-sector disk
    ├── boot.asm             # 16-bit real-mode MBR with BPB padding, segment setup & INT 0x13
    ├── boot.bin             # Generated multi-sector raw disk image (ignored by git)
    └── message.txt          # Secondary sector payload loaded by BIOS from disk
```

---

## Detailed Milestone Log

### Milestone: Phase 3 Completed — Multi-Sector Disk Loading & BPB Architecture
- **Date Completed:** 2026-10-26
- **Files Involved:** `SatnaOS/boot.asm`, `SatnaOS/Makefile`, `SatnaOS/message.txt`
- **Technical Validation:**
  - Implemented BPB filesystem reservation (`_start: jmp short start; nop; times 33 db 0`).
  - Utilized BIOS `INT 0x13` (`AH=0x02`, `AL=1`, `CH=0`, `CL=2`, `DH=0`) to load Sector 2 from disk to memory buffer `0x7E00`.
  - Added hardware error status detection via the Carry Flag (`jc error`).
  - Created automated build pipeline with `Makefile` using GNU `dd` to stitch Sector 1 (MBR) and Sector 2 (`message.txt`).
  - Validated in QEMU: Sector 2 text read into RAM buffer and printed via BIOS `INT 0x10`.

### Milestone: Phase 2 Architecture Refinement — Segment Normalization & Stack Setup
- **Date Completed:** 2026-10-26
- **Files Involved:** `SatnaOS/boot.asm`, `SatnaOS/boot.bin`
- **Technical Validation:**
  - Implemented inter-segment far jump `jmp 0x7c0:start` (Opcode `EA 05 00 C0 07`) to eliminate BIOS `CS` ambiguity.
  - Aligned data access with `ORG 0` and `DS = ES = 0x07C0`.
  - Initialized isolated downward stack at `SS = 0x0000`, `SP = 0x7C00` wrapped in `cli` and `sti` to avert dual-instruction interrupt hazards.
  - Assembled to 512 bytes with opcode verification (`EA`, `FA`, `B8 C0 07`, `8E D8`, `8E D0`, `BC 00 7C`, `FB`).

### Milestone: Portfolio Showcase Integration Created
- **Date Completed:** 2026-10-21
- **Files Involved:** `portfolio_export/research/satnaos-kernel/index.html`, `portfolio_export/project-card-snippet.html`
- **Technical Validation:**
  - Matched portfolio design tokens (`--paper: #fdfbe5`, `--ink: #121212`, `--serif`, `--mono`).
  - Integrated 3-column layout, Chart.js memory visualization, tabbed code walkthrough, and C++ mental models.
  - Linked interactive AI system explainer to existing `/api/gemini` Vercel endpoint.

### Milestone: Phase 2 Real-Mode Bootloader Verified
- **Date Completed:** 2026-10-20
- **Files Involved:** `SatnaOS/boot.asm`, `SatnaOS/boot.bin`
- **Technical Validation:**
  - Assembled flat 512-byte binary using `nasm -f bin boot.asm -o boot.bin`.
  - Verified exact 512-byte sector boundary ending with `0x55 0xAA` little-endian signature.
  - Executed in QEMU via `qemu-system-i386 -drive format=raw,file=boot.bin`.
  - Verified BIOS `INT 0x10` (`AH=0x0E`) teletype rendering of "Hello, World!".

