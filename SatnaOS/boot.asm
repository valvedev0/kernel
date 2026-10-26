ORG 0 ; set the origin to 0 for the bootloader
BITS 16 

_start:
    jmp short start ; jump to the start of the bootloader code
    nop ; padding to align the code

    times 33 db 0 ; fill the rest of the bootloader with zeros

start:
    jmp 0x7c0:step2 ; step2 is the label for the next part of the bootloader code


step2:
    cli ; clear interrupts
    mov ax, 0x07c0 ; set up the segment registers
    mov ds, ax
    mov es, ax
    mov ax, 0x00 
    mov ss, ax ; set stack segment to 0
    mov sp, 0x7c00 ; set stack pointer to 0x7c00
    sti ; enable interrupts

    ;read the message from the disk into memory
    mov ah, 2 ; BIOS function to read sectors from disk
    mov al, 1 ; number of sectors to read
    mov ch, 0 ; cylinder number
    mov cl, 2 ; sector number (starting from 1)
    mov dh, 0 ; head number
    mov bx, buffer ; buffer to store the read data
    int 0x13 ; call BIOS interrupt to read from disk
    jc error ; if carry flag is set, jump to error handling
  
    mov si, buffer ; load the address of the buffer into si
    call print ; call the print function to display the message
    jmp $

error:
    mov si, error_message ; load the address of the error message into si
    call print ; call the print function to display the error message
    jmp $ ; halt the system

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

error_message: db 'Error: Unable to read from disk.', 0 ; null-terminated error message


times 510 - ($ - $$) db 0 ; fill the rest of the boot sector with zeros
dw 0xaa55 ; boot sector signature    

buffer: 