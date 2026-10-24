org 0x7C00
bits 16

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    call clear_screen
    mov ax, 0xB800
    mov es, ax

game_loop:
    ; Check for keyboard input non-blockingly
    mov ah, 0x01
    int 0x16
    jz .no_key

    mov ah, 0x00
    int 0x16

    ; Map WASD keys to velocity
    cmp al, 'w'
    je .move_up
    cmp al, 's'
    je .move_down
    cmp al, 'a'
    je .move_left
    cmp al, 'd'
    je .move_right
    jmp .no_key

.move_up:
    mov byte [vel_x], 0
    mov byte [vel_y], -1
    jmp .no_key
.move_down:
    mov byte [vel_x], 0
    mov byte [vel_y], 1
    jmp .no_key
.move_left:
    mov byte [vel_x], -1
    mov byte [vel_y], 0
    jmp .no_key
.move_right:
    mov byte [vel_x], 1
    mov byte [vel_y], 0
    jmp .no_key

.no_key:
    ; Save current head position into history ffer
    movzx bx, byte [head_ptr]
    shl bx, 1
    mov al, [snake_x]
    mov [history + bx], al
    mov al, [snake_y]
    mov [history + bx + 1], al

    inc byte [head_ptr]
    and byte [head_ptr], 31

    ; Update head position based on velocity
    mov al, [vel_x]
    add [snake_x], al
    mov al, [vel_y]
    add [snake_y], al

    ; Check wall collisions
    mov al, [snake_x]
    cmp al, 80
    jae game_over
    mov al, [snake_y]
    cmp al, 25
    jae game_over

    ; Check food collision
    mov al, [snake_x]
    cmp al, [food_x]
    jne .skip_eat
    mov al, [snake_y]
    cmp al, [food_y]
    jne .skip_eat

    ; Food eaten, increment score and spawn new food
    inc byte [score]
    call spawn_food
    jmp .draw_all

.skip_eat:
    ; Erase oldest tail coordinate from buffer if not growing
    movzx bx, byte [tail_ptr]
    shl bx, 1
    mov al, [history + bx]
    mov [old_tail_x], al
    mov al, [history + bx + 1]
    mov [old_tail_y], al

    inc byte [tail_ptr]
    and byte [tail_ptr], 31

    ; Erase tail cell from screen
    mov al, [old_tail_y]
    mov bl, [old_tail_x]
    mov dx, 0x1020
    call draw_entity

.draw_all:
    ; Draw score display
    call draw_score

    ; Draw food
    mov al, [food_y]
    mov bl, [food_x]
    mov dx, 0x1C40
    call draw_entity

    ; Draw snake head
    mov al, [snake_y]
    mov bl, [snake_x]
    mov dx, 0x1A4F
    call draw_entity

    ; Delay frame rate
    call delay
    jmp game_loop

game_over:
    xor ah, ah
    int 0x16

    ; Reset game state
    mov word [snake_x], 0x0C28    ; snake_x = 40, snake_y = 12
    mov word [vel_x], 0x0001      ; vel_x = 1, vel_y = 0
    mov byte [score], 0
    mov word [head_ptr], 0        ; head_ptr = 0, tail_ptr = 0

    call clear_screen
    call spawn_food
    jmp game_loop

; Calculate VRAM offset and draw a character
draw_entity:
    push ax
    mov ah, 80
    mul ah
    xor bh, bh
    add ax, bx
    shl ax, 1
    mov di, ax
    pop ax
    mov [es:di], dx
    ret

draw_score:
    pusha
    xor di, di
    mov si, score_str
.print_label:
    lodsb
    test al, al
    jz .print_score
    mov ah, 0x1F
    stosw
    jmp .print_label

.print_score:
    mov al, [score]
    xor ah, ah
    mov bl, 10
    div bl
    push ax
    mov al, [esp]
    add al, '0'
    mov ah, 0x1F
    stosw
    mov al, [esp+1]
    add al, '0'
    mov ah, 0x1F
    stosw
    pop ax
    popa
    ret

spawn_food:
    pusha
    xor ah, ah
    int 0x1A
    mov ax, dx
    xor dx, dx
    mov cx, 80
    div cx
    mov [food_x], dl

    mov ax, dx
    xor dx, dx
    mov cx, 24
    div cx
    inc dl
    mov [food_y], dl
    popa
    ret

clear_screen:
    pusha
    mov ah, 0x06
    xor al, al
    mov bh, 0x1F
    xor cx, cx
    mov dx, 0x184F
    int 0x10
    popa
    ret

delay:
    ; Read Current BIOS timer tick count
    mov ax, 0x00
    int 0x1A
    mov bx, dx

.wait_tick:
    mov ah, 0x00
    int 0x1A
    cmp dx, bx
    je .wait_tick

    ret

snake_x:    db 40
snake_y:    db 12
food_x:     db 20
food_y:     db 20
vel_x:      db 1
vel_y:      db 0
score:      db 0
score_str:  db "SCR:", 0x00

head_ptr:   db 0
tail_ptr:   db 0
old_tail_x: db 0
old_tail_y: db 0
history:    times 64 db 0

times 510 - ($ - $$) db 0
dw 0xAA55
