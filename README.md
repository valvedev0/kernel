# SatnaOS: 32-Bit Multitasking x86 Operating System & Kernel

![Architecture](https://img.shields.io/badge/Architecture-x86%20(32--bit%20i686)-blue.svg)
![Mode](https://img.shields.io/badge/Mode-Real%20Mode%20%E2%86%92%20Protected%20Mode-darkgreen.svg)
![Status](https://img.shields.io/badge/Status-Active%20Engineering-orange.svg)
![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)

**SatnaOS** is a modular, 32-bit multitasking operating system kernel engineered from first principles for the x86 architecture. The project begins at the bare-metal Master Boot Record (MBR) and systematically constructs a complete, self-contained kernel architecture featuring protected mode execution, paging-based virtual memory, dynamic heap management, preemptive task scheduling, a Virtual File System (VFS) with FAT16 support, user-mode isolation (Ring 3), and an interactive shell.

---

## Architecture Overview

```mermaid
graph TD
    Hardware["Bare-Metal / QEMU Virtual Machine"]
    
    subgraph Bootstage["Boot & Hardware Initialization"]
        MBR["Stage 1: Real-Mode MBR (0x7C00)"]
        A20["A20 Gate & GDT Setup"]
        ProtMode["32-Bit Protected Mode Transition"]
        MBR --> A20 --> ProtMode
    end

    subgraph CoreKernel["SatnaOS Kernel Core"]
        IDT["IDT & PIC Interrupt Dispatcher"]
        VMM["Virtual Memory Manager (4KB Two-Level Paging)"]
        KHeap["Dynamic Kernel Heap (kmalloc / kfree)"]
        Sched["Preemptive Round-Robin Scheduler (PIT IRQ0)"]
    end

    subgraph StorageSubsys["Storage & Executable Subsystem"]
        ATA["ATA Disk Driver (PIO Mode)"]
        VFS["Virtual File System (VFS)"]
        FAT["FAT16 Filesystem Driver"]
        ELF["ELF32 Binary Loader"]
        ATA --> VFS
        FAT --> VFS
        VFS --> ELF
    end

    subgraph UserLand["User Space (Ring 3) & Console"]
        Syscall["Syscall Interface (int 0x80)"]
        KB["PS/2 Keyboard Driver"]
        Shell["Interactive Command Shell"]
    end

    Hardware --> Bootstage
    ProtMode --> CoreKernel
    CoreKernel --> StorageSubsys
    StorageSubsys --> UserLand
    CoreKernel --> UserLand
```

---

## Engineering Phases & Roadmap

System development is structured into 8 sequential engineering phases. Real-time checklist and progress logs are tracked in [guides/GOALS.md](guides/GOALS.md), and in-depth architectural breakdowns are documented in [guides/KERNEL_GUIDE.md](guides/KERNEL_GUIDE.md).

| Phase | Milestone | Description | Status |
| :---: | :--- | :--- | :---: |
| **01** | **Toolchain & Environment** | Bare-metal cross-compilation toolchain (`i686-elf`), NASM, QEMU, GDB. | Verified |
| **02** | **Real-Mode Bootloader** | 512-byte MBR boot sector at `0x7C00`, BIOS interrupts, text output. | **Completed** |
| **03** | **Disk I/O & Real-Mode Interrupts** | Multi-sector loading via BIOS `INT 0x13`, disk error handling routines. | In Progress |
| **04** | **32-Bit Protected Mode Switch** | A20 Gate activation, Global Descriptor Table (GDT), CR0 PE bit, far jump. | Upcoming |
| **05** | **Interrupts, Paging & Memory Heap** | IDT configuration, 8259 PIC remap, two-level 4KB paging, `kmalloc`/`kfree`. | Upcoming |
| **06** | **Multitasking & Process Management** | TSS setup, context switching, Process Control Blocks, PIT scheduler. | Upcoming |
| **07** | **VFS, FAT16 & ELF Executable Loading**| ATA disk driver, FAT16 filesystem implementation, ELF32 loader, Ring 3. | Upcoming |
| **08** | **Hardware Drivers & Interactive Shell**| PS/2 keyboard IRQ handler, VGA text console, interactive CLI shell. | Upcoming |

---

## Repository Structure

```
.
├── .gitignore               # Ignored build artifacts, local dashboard, and internal agent docs
├── README.md                # Public repository showcase & quickstart documentation
├── guides/
│   ├── GOALS.md             # Operational phase tracker, file inventory, and changelog
│   ├── KERNEL_GUIDE.md      # Deep technical knowledge base & architectural reference
│   ├── ASSEMBLY_GUIDE.md    # Low-level x86 assembly primer for C++ engineers
│   └── SETUP_GUIDE.md       # Toolchain, QEMU execution, and GDB debugging manual
└── SatnaOS/
    ├── boot.asm             # 16-bit real-mode MBR boot sector (origin 0x7c00)
    └── boot.bin             # Assembled 512-byte raw bootable disk image (git-ignored)
```

---

## Quickstart & Build Instructions

### Prerequisites
Ensure the following tools are installed on your host system:
- **NASM** (Netwide Assembler)
- **QEMU** (`qemu-system-i386` or `qemu-system-x86_64`)

```bash
# On Debian/Ubuntu systems
sudo apt update
sudo apt install -y nasm qemu-system-x86
```

### Assembling & Running the Boot Sector

1. **Assemble the boot sector to a flat binary:**
   ```bash
   cd SatnaOS
   nasm -f bin boot.asm -o boot.bin
   ```

2. **Verify image size (must be exactly 512 bytes):**
   ```bash
   ls -la boot.bin
   ```

3. **Launch in QEMU:**
   ```bash
   qemu-system-i386 -drive format=raw,file=boot.bin
   ```

---

## Dedicated Guides & Knowledge Base

- **[guides/KERNEL_GUIDE.md](guides/KERNEL_GUIDE.md):** Textbook-grade systems reference covering the x86 real-mode execution model, memory topology, opcode decodings, and future subsystem blueprints.
- **[guides/ASSEMBLY_GUIDE.md](guides/ASSEMBLY_GUIDE.md):** x86 assembly manual translating CPU registers, memory segments, calling conventions, and string instructions into intuitive C++ mental models.
- **[guides/SETUP_GUIDE.md](guides/SETUP_GUIDE.md):** Operational manual for NASM commands, QEMU monitor inspection, GDB remote debugging, and triple-fault triage.
- **[guides/GOALS.md](guides/GOALS.md):** Operational milestone checklist, toolchain inventory, and phase completion logs.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
