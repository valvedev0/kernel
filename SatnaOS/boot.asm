ORG 0x7c00
BITS 16 

start:
    ; setup to print hello world from the bootloader
    mov si, message
    call print
    jmp $

print:
    mov bx, 0 ; set bx to 0 for the string index
.loop:
    lodsb ; load byte at [si] into al and increment si
    cmp al, 0 ; check if we reached the end of the string
    je .done ; if al is 0, we are done
    call print_char ; print the character in al
    jmp .loop ; repeat the loop
.done:
    ret
print_char:
    mov ah, 0eh ; BIOS teletype function
    int 0x10 ; call BIOS interrupt to print character in al
    ret    
message db 'Hello, World!', 0 ; null-terminated string

times 510 - ($ - $$) db 0 ; fill the rest of the boot sector with zeros
dw 0xaa55 ; boot sector signature    