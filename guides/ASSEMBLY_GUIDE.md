# x86 Assembly for Systems & C++ Engineers

> **A Low-Level Systems Primer for SatnaOS Kernel Development**  
> Tailored for developers with intermediate C/C++ knowledge transitioning to bare-metal assembly.

---

## Navigation & Quick Reference
- [1. Mental Model: C++ vs. x86 Assembly](#1-mental-model-c-vs-x86-assembly) *(Line ~18)*
- [2. The x86 Register File](#2-the-x86-register-file) *(Line ~55)*
- [3. Memory Addressing: Flat Pointers vs. Real-Mode Segments](#3-memory-addressing-flat-pointers-vs-real-mode-segments) *(Line ~105)*
- [4. Core Instructions Reference](#4-core-instructions-reference) *(Line ~150)*
- [5. String Primitives: The `lodsb` Family](#5-string-primitives-the-lodsb-family) *(Line ~205)*
- [6. The Hardware Stack & Subroutines](#6-the-hardware-stack--subroutines) *(Line ~240)*
- [7. NASM Directives vs. Machine Instructions](#7-nasm-directives-vs-machine-instructions) *(Line ~285)*
- [8. Critical Pitfalls for C++ Developers](#8-critical-pitfalls-for-c-developers) *(Line ~325)*

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

## 3. Memory Addressing: Flat Pointers vs. Real-Mode Segments

In modern C++ (and in x86 Protected Mode), pointers are **flat linear addresses**:
```cpp
uint8_t* ptr = reinterpret_cast<uint8_t*>(0x7C00); // Points directly to physical 0x7C00
```

In 16-bit Real Mode, physical memory is 20-bit, but registers are only 16-bit. Intel solved this with **Segment:Offset Addressing**:
$$\text{Physical Address} = (\text{Segment} \times 16) + \text{Offset}$$

### The Overlapping Segment Phenomenon
Notice that multiple `Segment:Offset` pairs can point to the **exact same physical byte**:
- `0x0000:0x7C00` $\implies (0 \times 16) + 0x7C00 = 0x07C00$
- `0x07C0:0x0000` $\implies (0x07C0 \times 16) + 0 = 0x07C00$

> **Key Rule for Bootloaders:** If your `DS` (Data Segment) register is set to `0x0000`, `[org 0x7c00]` correctly resolves all labels. If your BIOS boots with `CS = 0x07C0` and `IP = 0x0000`, accessing labels assuming `DS = 0` will fail unless segment registers are explicitly normalized!

---

## 4. Core Instructions Reference

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

### Branching & Control Flow
```nasm
jmp target          ; Unconditional jump to label 'target'
je label            ; Jump if Equal (Zero Flag ZF == 1)
jne label           ; Jump if Not Equal (Zero Flag ZF == 0)
jc error_handler    ; Jump if Carry Flag is set (CF == 1, standard error indicator)
jnc success         ; Jump if Carry Flag is clear (CF == 0)
```

---

## 5. String Primitives: The `lodsb` Family

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

## 6. The Hardware Stack & Subroutines

The x86 stack is **full-descending**:
- It grows from **high addresses toward low addresses**.
- `push ax`: Decrements `SP` by 2, then writes `AX` to `[SS:SP]`.
- `pop ax`: Reads `AX` from `[SS:SP]`, then increments `SP` by 2.

```
High Memory
| ...              |
| Return Address   | <- SP after 'call print'
| ...              | <- SP grows downward during 'push'
Low Memory
```

### How `call` and `ret` Work Under the Hood
1. `call print`:
   - CPU pushes the address of the next instruction (the Return Address) onto `[SS:SP]`.
   - CPU jumps to `print` by assigning its address to `IP`.
2. Inside `print`:
   - The routine executes its operations.
3. `ret`:
   - CPU pops the top word off the stack directly into `IP`.
   - Execution resumes immediately after the original `call`.

---

## 7. NASM Directives vs. Machine Instructions

Not everything in an assembly file corresponds to CPU opcodes. NASM distinguishes between:

| Syntax | Type | Purpose |
| :--- | :--- | :--- |
| `mov`, `int`, `ret` | **Machine Instruction** | Assembled into literal hardware CPU opcodes. |
| `ORG 0x7C00` | **Assembler Directive** | Sets calculation base for labels. Produces zero machine bytes. |
| `BITS 16` | **Assembler Directive** | Sets CPU mode generation (16-bit vs 32-bit). Produces zero machine bytes. |
| `db`, `dw`, `dd` | **Data Definition** | Emits literal raw bytes (`db`), words (`dw`, 2 bytes), or dwords (`dd`, 4 bytes). |
| `times N db 0` | **Macro Directive** | Repeats byte definition $N$ times. Used for padding sectors. |
| `$` and `$$` | **NASM Symbols** | `$` = current byte position; `$$` = start of current section. |

---

## 8. Critical Pitfalls for C++ Developers

1. **Uninitialized Segment Registers:**
   - C++ developers take for granted that pointers point to flat memory. In real mode, accessing `[my_var]` calculates `DS * 16 + offset`. If `DS` is uninitialized or garbage, your read hits random BIOS memory! Always initialize `DS`, `ES`, and `SS`.
2. **Missing `ORG 0x7C00`:**
   - Without `ORG 0x7C00`, NASM assumes line 1 is address `0x0000`. Memory references to variables will be offset by `-0x7C00`, reading garbage from the Interrupt Vector Table.
3. **Mismatched Register Sizes:**
   - `mov [bx], eax` in 16-bit mode writes 4 bytes. If your memory buffer only has 1 or 2 bytes allocated, you will silently corrupt adjacent memory.
4. **Clobbering Registers Across Calls:**
   - In assembly, there is no automatic parameter preservation. If subroutine `B` modifies `AX`, subroutine `A` loses its previous `AX` value unless explicitly `push`ed and `pop`ped.

