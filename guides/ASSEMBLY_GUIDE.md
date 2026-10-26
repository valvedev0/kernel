# x86 Assembly for Systems & C++ Engineers

> **A Low-Level Systems Primer for SatnaOS Kernel Development**  
> Tailored for developers with intermediate C/C++ knowledge transitioning to bare-metal assembly.

---

## Navigation & Quick Reference
- [1. Mental Model: C++ vs. x86 Assembly](#1-mental-model-c-vs-x86-assembly) *(Line ~20)*
- [2. The x86 Register File](#2-the-x86-register-file) *(Line ~60)*
- [3. Memory Segmentation: Real-World Analogies & Mechanics](#3-memory-segmentation-real-world-analogies--mechanics) *(Line ~115)*
  - [The Apartment Complex & City Street Analogy](#the-apartment-complex--city-street-analogy)
  - [Segment:Offset Arithmetic in C++](#segmentoffset-arithmetic-in-c)
  - [The Overlapping Segments Phenomenon](#the-overlapping-segments-phenomenon)
  - [Why `ORG 0` with `jmp 0x7c0:start`?](#why-org-0-with-jmp-0x7c0start)
- [4. The Hardware Stack: Mechanics & Safety](#4-the-hardware-stack-mechanics--safety) *(Line ~210)*
  - [The Downward Spelunking / Spring-Loaded Dispenser Analogy](#the-downward-spelunking--spring-loaded-dispenser-analogy)
  - [Why `SS = 0x0000` and `SP = 0x7C00`?](#why-ss--0x0000-and-sp--0x7c00)
  - [The Dual-Instruction Hazard: Why `cli` and `sti`?](#the-dual-instruction-hazard-why-cli-and-sti)
- [5. Core Instructions Reference](#5-core-instructions-reference) *(Line ~305)*
- [6. String Primitives: The `lodsb` Family](#6-string-primitives-the-lodsb-family) *(Line ~345)*
- [7. NASM Directives vs. Machine Instructions](#7-nasm-directives-vs-machine-instructions) *(Line ~385)*
- [8. Critical Pitfalls for C++ Developers](#8-critical-pitfalls-for-c-developers) *(Line ~425)*

---

## 1. Mental Model: C++ vs. x86 Assembly

In C++, the compiler manages storage, register allocation, type conversions, and stack frames:

```cpp
// C++ High-Level Code
int add(int a, int b) {
    return a + b;
}
```

In assembly, there are **no types, no variables, and no automatic scope**:
- A "variable" is just a memory address or a CPU register.
- A "pointer dereference" (`*ptr`) is an explicit bracket operand (`[reg]`).
- A "type cast" is selecting a register size (`AL` = 1 byte, `AX` = 2 bytes, `EAX` = 4 bytes).
- A "function" is just a label (memory offset) navigated via `call` and `ret`.

### Concept Comparison Table

| C++ Feature | Assembly Reality | Architectural Impact |
| :--- | :--- | :--- |
| `uint8_t` | `AL`, `AH`, `BL`, `CL`, `DL` | 8-bit registers |
| `uint16_t` | `AX`, `BX`, `CX`, `DX`, `SI`, `DI`, `SP`, `BP` | 16-bit registers (Real Mode native) |
| `uint32_t` | `EAX`, `EBX`, `ECX`, `EDX`, `ESI`, `EDI`, `ESP`, `EBP` | 32-bit registers (Protected Mode native) |
| `*ptr` (Dereference) | `[si]`, `[bx]`, `[ebx]` | Reading memory at the contained address |
| `ptr++` | `inc si` or auto-increment via `lodsb` | Explicit pointer incrementation |
| `if (x == y)` | `cmp ax, bx` followed by `je label` | Setting CPU status flags (`ZF`) then conditional branch |
| `while (true)` | `label: ... jmp label` | Unconditional relative jump |
| Function call `foo()` | `call foo` $\implies$ push `IP`, jump; `ret` $\implies$ pop `IP` | Manual stack management |

---

## 2. The x86 Register File

In 16-bit Real Mode, registers are 16 bits wide, but some can be split into independent high/low 8-bit registers:

```
+------------------------ EAX (32-bit: Protected Mode) ------------------------+
                          +------------ AX (16-bit: Real Mode) ------------+
                          +--- AH (8-bit High) ---+--- AL (8-bit Low) -----+
```

### General Purpose Registers

| Register | Traditional Name | Specialized Hardware Roles |
| :--- | :--- | :--- |
| **`AX` (`AH`/`AL`)** | **Accumulator** | Arithmetic operations, I/O port instructions (`in`/`out`), BIOS function parameters. |
| **`BX` (`BH`/`BL`)** | **Base Register** | Memory addressing base, BIOS display page parameter (`BH`). |
| **`CX` (`CH`/`CL`)** | **Counter** | Loop iterations (`loop`), bit-shift amounts (`CL`), string operations (`rep`). |
| **`DX` (`DH`/`DL`)** | **Data Register** | I/O port addressing, multiply/divide overflow, drive numbers (`DL = 0x80`). |
| **`SI`** | **Source Index** | Pointer for string read operations (`lodsb`, `movsb`). |
| **`DI`** | **Destination Index**| Pointer for string write operations (`stosb`, `movsb`). |
| **`BP`** | **Base Pointer** | Stack frame base (equivalent to C++ function frame pointer). |
| **`SP`** | **Stack Pointer** | Points to current top of the stack (grows downwards toward `0x0000`). |

### Segment Registers (Real Mode Addressing)

| Register | Name | Role |
| :--- | :--- | :--- |
| **`CS`** | **Code Segment** | Points to segment containing currently executing instructions (`CS:IP`). |
| **`DS`** | **Data Segment** | Default segment used for global and static variable access (`DS:offset`). |
| **`SS`** | **Stack Segment** | Segment containing the current execution stack (`SS:SP`). |
| **`ES`** | **Extra Segment** | General-purpose segment, often used as target buffer for BIOS disk reads (`ES:BX`). |

---

## 3. Memory Segmentation: Real-World Analogies & Mechanics

### The Apartment Complex & City Street Analogy
To understand why segmentation exists, consider this hardware dilemma:
- In 1978, the Intel 8086 processor had a **20-bit physical address bus**. This meant the CPU could access $2^{20} = 1,048,576\text{ bytes } (1\text{ MB})$ of RAM.
- However, all internal CPU registers (`AX`, `BX`, `SI`, `IP`) were only **16 bits wide**.
- A 16-bit register can only count from `0` to `65,535` (`64 KB`).

**The Problem:** How does a postal delivery worker visit **1,000,000 houses** if their delivery clipboard can only write numbers up to **65,535**?

**The Real-World Solution:** You divide the city into **Blocks (Segments)**, and write down two numbers:
1. **The Block Number (Segment):** Identifies which block of the city you are in.
2. **The House Number (Offset):** Identifies the door within that block (0 to 65,535).

Intel designed every "Block" to start every **16 bytes** (a 16-byte boundary is called a **paragraph**):

$$\text{Physical Address} = (\text{Segment} \times 16) + \text{Offset} = (\text{Segment} \ll 4) + \text{Offset}$$

```
Segment Register (16-bit):  [ 0x07C0 ]  ---(shift left 4 bits)--->  0x07C00
Offset (e.g. IP / SI):      [ 0x0031 ]  -------------------------> +0x00031
                                                                   ---------
Physical Memory Address:                                            0x07C31
```

### Segment:Offset Arithmetic in C++
If you were writing an x86 emulator in C++, you would implement memory addressing like this:

```cpp
#include <cstdint>

// Emulated 1MB Physical Memory Space
uint8_t physical_memory[1024 * 1024]; 

uint8_t* translate_address(uint16_t segment, uint16_t offset) {
    // Shift segment left by 4 (multiply by 16) and add the offset
    uint32_t physical_address = (static_cast<uint32_t>(segment) << 4) + offset;
    return &physical_memory[physical_address];
}

// Example: Resolving DS:SI where DS = 0x07C0 and SI = 0x0031
uint8_t* byte_ptr = translate_address(0x07C0, 0x0031); 
// Points directly to physical address 0x07C31!
```

### The Overlapping Segments Phenomenon
Because segments start every 16 bytes rather than every 64 KB, segments **heavily overlap**. Multiple different `Segment:Offset` combinations point to the **exact same physical byte of RAM**:

- `0x0000:0x7C00` $\implies (0x0000 \times 16) + 0x7C00 = \mathbf{0x07C00}$
- `0x07C0:0x0000` $\implies (0x07C0 \times 16) + 0x0000 = \mathbf{0x07C00}$
- `0x07B0:0x0100` $\implies (0x07B0 \times 16) + 0x0100 = \mathbf{0x07C00}$

### Why `ORG 0` with `jmp 0x7c0:start`?
When the BIOS boots, different BIOS manufacturers handle hand-off differently:
- Some BIOSes jump to `0x0000:0x7C00` (`CS = 0x0000`, `IP = 0x7C00`).
- Other BIOSes jump to `0x07C0:0x0000` (`CS = 0x07C0`, `IP = 0x0000`).

Both land on physical address `0x7C00`, but your **`CS` (Code Segment) register is unpredictable!**

If your code relies on `CS` being `0x07C0`, but the BIOS booted with `CS = 0x0000`, relative jumps and calls could behave unexpectedly.

To eliminate this ambiguity, defensive bootloaders use a **Far Jump**:
```nasm
ORG 0               ; Tell assembler label offsets start at 0 within this segment
BITS 16 

jmp 0x7c0:start     ; Far jump explicitly forces CS = 0x07C0 and IP = offset of start!

start:
    mov ax, 0x07c0
    mov ds, ax      ; DS = 0x07C0
    mov es, ax      ; ES = 0x07C0
```

1. **`jmp 0x7c0:start`:** Immediately forces `CS` to `0x07C0`. It standardizes the CPU state regardless of what weird BIOS loaded you.
2. **`ORG 0`:** Because our base segment is `0x07C0` ($0x07C0 \times 16 = \text{physical } 0x7C00$), the first instruction of our bootloader sits at offset `0` of this segment!
3. **`mov ds, ax`:** Data Segment is also set to `0x07C0`. Now any label like `mov si, message` loads `SI` with an offset relative to `0`. When `lodsb` accesses `[DS:SI]`, the CPU calculates $(0x07C0 \times 16) + \text{offset} = 0x7C00 + \text{offset}$, hitting the exact string in physical RAM.

---

## 4. The Hardware Stack: Mechanics & Safety

### The Downward Spelunking / Spring-Loaded Dispenser Analogy
In software, a stack is Last-In, First-Out (LIFO). 
- In a cafeteria, clean plates sit in a spring-loaded cylinder: you push a plate onto the top, and you pop a plate off the top.
- **The x86 Hardware Twist:** The x86 stack is **full-descending**—it grows **downwards from high memory addresses toward low memory addresses**.

Think of a mountain climber anchoring a rope at a high ledge and rappelling downward into a cavern:
- The base anchor point is the **Stack Segment (`SS`)**.
- The climber's current depth is the **Stack Pointer (`SP`)**.

```
High Memory Address
| ...                          |
| [Physical 0x7C00]            | <-- Top of Stack (Initial SP = 0x7C00)
| [Physical 0x7BFE] (2 bytes)  | <-- SP after first 'push' or 'call'
| [Physical 0x7BFC] (2 bytes)  | <-- SP after second 'push'
|                              |      Stack grows DOWNWARD toward 0x0000
v                              v
Low Memory Address (0x0500)
```

### What Happens During `push`, `pop`, `call`, and `ret`?

#### 1. `push ax`
```nasm
SP = SP - 2             ; Move down 2 bytes in memory
[SS:SP] = AX            ; Store 16-bit register value at new stack location
```

#### 2. `pop ax`
```nasm
AX = [SS:SP]            ; Read 16-bit value from current stack location
SP = SP + 2             ; Move up 2 bytes in memory
```

#### 3. `call print`
When calling a function, the CPU must remember where to come back to:
```nasm
SP = SP - 2             ; Decrement stack pointer
[SS:SP] = IP            ; Push address of instruction AFTER 'call' (Return Address)
IP = print              ; Jump to target subroutine
```

#### 4. `ret`
```nasm
IP = [SS:SP]            ; Pop Return Address from stack into Instruction Pointer
SP = SP + 2             ; Clean up stack pointer (resume original code)
```

---

### Why `SS = 0x0000` and `SP = 0x7C00`? (The Critical Safety Reason)

Look at where memory is laid out when our bootloader executes:
- Our 512-byte boot sector lives from **`0x7C00` to `0x7DFF`**.
- The conventional memory below us from **`0x0500` to `0x7BFF`** (~30 KB) is **completely free and unused RAM**.

```
Memory Layout:
[0x00500] ---------------------------------------------
          | Free Conventional Memory (~30 KB)         |
          | (SAFE ZONE: Stack grows DOWNWARD here)    |
[0x07BFE] | <-- Stack Pointer moves down into here    |
[0x07C00] =============================================
          | Bootloader Code & Data (512 Bytes)        |
          | (DANGER ZONE: Do not overwrite!)          |
[0x07DFF] =============================================
```

- By setting `SS = 0x0000` and `SP = 0x7C00`:
  $$\text{Top of Stack Physical} = (0x0000 \times 16) + 0x7C00 = \mathbf{0x07C00}$$
- Because the stack grows **downward**, every `call` and `push` writes into `0x7BFE`, `0x7BFC`, `0x7BFA`...
- **The stack grows away from our code!**
- If we accidentally pointed the stack above `0x7C00` and grew into our code, calling a function would write return addresses over our instructions, causing an instant triple fault or infinite crash loop!

---

### The Dual-Instruction Hazard: Why `cli` and `sti`?

Notice how the stack is initialized in [`SatnaOS/boot.asm`](file:///home/praveen/Documents/vs/kernel/SatnaOS/boot.asm):

```nasm
cli             ; 1. Clear Interrupt Flag (disable maskable interrupts)
mov ax, 0x00 
mov ss, ax      ; 2. Update Stack Segment
mov sp, 0x7c00  ; 3. Update Stack Pointer
sti             ; 4. Set Interrupt Flag (re-enable interrupts)
```

**Why is disabling interrupts necessary here?**
Setting up a new stack requires changing **two separate registers**: `SS` and `SP`.

Imagine what happens if a hardware interrupt (such as the motherboard timer tick, IRQ0) fires **between line 2 and line 3**:
1. The CPU has updated `SS = 0x0000`.
2. But `SP` still holds whatever random, uninitialized garbage was in it from the BIOS!
3. The hardware interrupt arrives: the CPU automatically tries to push the CPU flags and return address onto `[SS:SP]`.
4. Because `SP` is garbage, the CPU writes data to an unknown, random memory address, potentially corrupting BIOS data or memory-mapped hardware.
5. The CPU crashes immediately.

By wrapping the two instructions in `cli` and `sti`, you guarantee that **no hardware interrupt can interrupt the CPU while the stack is half-configured**.

---

## 5. Core Instructions Reference

### Data Movement
```nasm
mov ax, 0x1234      ; AX = 0x1234 (immediate value)
mov bx, ax          ; BX = AX (register-to-register)
mov ax, [0x7C00]    ; AX = 16-bit word at memory address 0x7C00
mov [bx], al        ; Store byte AL into memory address pointed to by BX
```

### Arithmetic & Comparison
```nasm
add ax, 5           ; AX = AX + 5
sub bx, 1           ; BX = BX - 1
cmp al, 0           ; Compute (AL - 0), discard result, update CPU flags (ZF, CF, SF)
```

### Branching, Jumps & The Carry Flag
```nasm
jmp target          ; Unconditional near jump to label 'target'
jmp short target    ; Short jump (1-byte relative offset: -128 to +127 bytes, saves code space)
jmp 0x07c0:target   ; Far inter-segment jump (reloads CS with segment and IP with offset)
je label            ; Jump if Equal (Zero Flag ZF == 1)
jne label           ; Jump if Not Equal (Zero Flag ZF == 0)
jc error_handler    ; Jump if Carry Flag is set (CF == 1, hardware error indicator)
jnc success         ; Jump if Carry Flag is clear (CF == 0, operation succeeded)
```

#### The Carry Flag (`CF`) as the Hardware Error Indicator
In C++, you check `if (!success)` or inspect `errno`. In x86 assembly, low-level firmware functions (like BIOS `INT 0x13` disk reads) use the **Carry Flag (`CF`)** in the `EFLAGS` register:
- **`CF = 0`:** The operation succeeded; data is written into memory.
- **`CF = 1`:** A hardware error occurred; `AH` holds the error status code.
- **`jc error`:** Directly tests `CF` and branches to error recovery if true.

---

## 6. String Primitives: The `lodsb` Family

In C++, iterating over a C-string looks like:
```cpp
const char* si = message;
while (*si != '\0') {
    print_char(*si++);
}
```

In x86 assembly, the CPU provides hardware-accelerated string instructions:

```nasm
lodsb   ; AL = [DS:SI] ; then SI = SI + 1 (if DF == 0)
```

- **How it works:**
  1. Reads one byte from memory at address `DS:SI` into `AL`.
  2. If the Direction Flag (`DF`) is `0` (cleared via `cld`), `SI` automatically increments by 1.
  3. If `DF` is `1` (set via `std`), `SI` decrements by 1.
- **Related String Instructions:**
  - `stosb`: Writes `AL` to `[ES:DI]` and advances `DI`.
  - `movsb`: Copies byte from `[DS:SI]` to `[ES:DI]` and advances both `SI` and `DI`.

---

## 7. NASM Directives vs. Machine Instructions

Not everything in an assembly file corresponds to CPU opcodes. NASM distinguishes between:

| Syntax | Type | Purpose |
| :--- | :--- | :--- |
| `mov`, `int`, `ret` | **Machine Instruction** | Assembled into literal hardware CPU opcodes. |
| `ORG 0` | **Assembler Directive** | Sets calculation base for labels within the active segment. |
| `BITS 16` | **Assembler Directive** | Sets CPU mode generation (16-bit vs 32-bit). Produces zero machine bytes. |
| `db`, `dw`, `dd` | **Data Definition** | Emits literal raw bytes (`db`), words (`dw`, 2 bytes), or dwords (`dd`, 4 bytes). |
| `times N db 0` | **Macro Directive** | Repeats byte definition $N$ times. Used for padding sectors. |
| `$` and `$$` | **NASM Symbols** | `$` = current byte position; `$$` = start of current section. |

---

## 8. Critical Pitfalls for C++ Developers

1. **Uninitialized Segment Registers:**
   - In real mode, accessing `[my_var]` calculates `DS * 16 + offset`. If `DS` is uninitialized, your read hits random memory. Always normalize `DS`, `ES`, and `SS`.
2. **Mismatched Register Sizes:**
   - `mov [bx], eax` in 16-bit mode writes 4 bytes. If your memory buffer only has 1 or 2 bytes allocated, adjacent memory is silently overwritten.
3. **Clobbering Registers Across Calls:**
   - In assembly, there is no automatic parameter preservation. If subroutine `B` modifies `AX`, subroutine `A` loses its previous `AX` value unless explicitly `push`ed and `pop`ped.
