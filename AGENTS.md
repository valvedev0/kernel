# Universal Agent Guidelines & Engineering Standards: SatnaOS

This document defines the universal instruction set, architectural guidelines, and quality standards for all development across the entire lifecycle of the **SatnaOS** kernel repository. Every AI agent and contributor interacting with this repository must strictly adhere to the rules outlined below.

---

## 1. Professionalism & Engineering Standards
- **Industry-Grade Quality:** Every file, module, script, and documentation page must meet high-caliber systems engineering standards. 
- **Code Hygiene:** 
  - Code must be cleanly indented, modular, and thoroughly commented with architectural rationale (explaining *why*, not just *what*).
  - Maintain defensive programming: zero unhandled segment boundaries, explicit stack initializations, and robust error checking (e.g., carry flags, status registers).
- **Clean Git & Repository Tree:**
  - No dangling binaries, test artifacts, or temporary dump files outside of structured build directories.
  - Keep root directory organized: core architecture docs, clear build tooling, and segregated source components.

---

## 2. Absolute Prohibition of Course References (Zero-Course Rule)
- **Strict Rule:** **NEVER** mention, imply, or reference any online course, video tutorial, lecture series, or external course syllabus anywhere in this repository.
- **Framing:** The repository must be presented as a **custom, self-directed systems engineering project** designed, engineered, and executed in structured engineering phases.
- **Terminology:**
  - Replace any term like *"course progress"* or *"course milestones"* with **"Engineering Phases"**, **"Phase Progress"**, or **"System Milestones"**.
  - Commit messages, documentation, and code comments must reflect original engineering design decisions from first principles.

---

## 3. Dedicated Documentation Architecture
The project maintains a strict separation of concerns across documentation files:

| Document | Primary Role & Content Scope |
| :--- | :--- |
| **`README.md`** | Public-facing GitHub repository showcase. Features badges, architectural overview, quickstart instructions, hardware specs, and milestone summaries suitable for open-source consumers and technical recruiters. |
| **`GOALS.md`** | Operational status and milestone tracker. Tracks checklist items across phases, maintains an active file tree inventory, records verified tool versions, and logs phase completion dates. Kept structured and concise. |
| **`KERNEL_GUIDE.md`** | **The Deep Technical Knowledge Base ("Learner's Heaven").** A comprehensive, textbook-quality reference detailing every phase. Contains instruction-by-instruction breakdowns, hardware register mechanics, knowledge graphs (Mermaid), memory maps, opcode decoding tables, and underlying computer architecture principles. |
| **`roadmap.html`** | Interactive, browser-based visual GUI dashboard for tracking phase progression with interactive local persistence. |

---

## 4. Portfolio & Web Showcase Integration
- All technical achievements, architecture diagrams, and phase summaries must be written with dual utility:
  1. Direct project documentation.
  2. Ready-to-publish showcase content for the author's portfolio website (hosted on GitHub Pages and Vercel).
- Maintain concise "Executive Summaries" and clean architectural highlights for each phase that can be effortlessly ported into portfolio project cards, interactive case studies, and engineering blog posts.

---

## 5. System Architecture & Toolchain Specifications
- **Target Architecture:** 32-bit x86 (`i686` flat memory model, Protected Mode).
- **Tooling Standards:**
  - Assembler: **NASM** (Netwide Assembler) with explicit syntax (`[org 0x7c00]`, `bits 16`, `bits 32`).
  - Compiler: Dedicated freestanding cross-compiler (`i686-elf-gcc`, `i686-elf-ld`) to ensure zero host OS/glibc contamination.
  - Emulator: **QEMU** (`qemu-system-i386`, `qemu-system-x86_64`) using explicit raw disk mounting (`-drive format=raw,file=...`).
  - Debugger: **GDB** via QEMU remote target (`target remote localhost:1234`).

