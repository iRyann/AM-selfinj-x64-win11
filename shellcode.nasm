[bits 64]

section .text
global _start

_start:
    and rsp, -16              ; Alignement Stack (ABI)

    ; ---------------------------------------------------------
    ; 1 & 2) Initialisation et recherche de Kernel32 (Code précédent)
    ; ---------------------------------------------------------
    call get_ldr_head
    test rax, rax
    jz die
    mov r14, rax              ; R14 = Sentinel

    lea rcx, [rel w_kernel32]
    mov rdx, r14
    call walk_to_module_dllbase
    test rax, rax
    jz die
    mov r15, rax              ; R15 = Kernel32 DllBase

    ; ---------------------------------------------------------
    ; 3) Construire export context kernel32
    ; ---------------------------------------------------------
    mov rcx, r15              ; RCX = DllBase
    call get_export_ctx       ; Vérifie le PE Header
    test rax, rax
    jz die
    
    ; Dans cette version simplifiée, le Context EST la DllBase.
    ; Cela suffit pour résoudre n'importe quel export.
    mov r12, rax              ; R12 = Export Context (DllBase)

    ; ---------------------------------------------------------
    ; 4) Résoudre GetProcAddress et GetModuleHandleA
    ; ---------------------------------------------------------
    
    ; --- Résolution de GetProcAddress ---
    lea rdx, [rel a_GetProcAddress] ; RDX = "GetProcAddress"
    mov rcx, r12                    ; RCX = Context (Base)
    call resolve_export_by_name
    test rax, rax
    jz die
    mov r13, rax                    ; R13 = pGetProcAddress

    ; --- Résolution de GetModuleHandleA ---
    lea rdx, [rel a_GetModuleHandleA]
    mov rcx, r12
    call resolve_export_by_name
    test rax, rax
    jz die
    mov rbx, rax                    ; RBX = pGetModuleHandleA

    ; --- SUCCÈS ---
    ; R13 = &GetProcAddress
    ; RBX = &GetModuleHandleA
    jmp _suite_du_code

die:
    int 3
_suite_du_code:
    ; Votre payload ici...
    jmp _suite_du_code

; get_ldr_head: retourne un pointeur stable vers LIST_ENTRY head (InMemoryOrderModuleList)
; OUT: RAX = head (LIST_ENTRY*)
get_ldr_head:
  xor rax, rax
  mov rax, gs:[0x60] ; Get address of PEB struct
  ; According to "Data structure alignment" requirement
  ; We've to consider a 4 bytes spacing between
  ; Reserved[2] and Reserved[3]
  mov rax, [rax+ 0x18] ; Get address of PEB_LDR_DATA
  add rax, 0x20 ; Get address of InMemoryOrderModuleList
  ret

; =============================================================
; walk_to_module_dllbase
; IN:  RDX = Pointeur vers le head (dans le PEB)
; IN:  RCX = WCHAR* nom du module
; OUT: RAX = DllBase ou 0
; =============================================================

walk_to_module_dllbase:
    mov r8, rdx ; R8 = Sauvegarde de la Tête (Sentinelle) pour fin de boucle
    mov rdx, [rdx] ; RDX = Premier Module (Flink)

_scan_loop:
    cmp rdx, r8
    je _not_found ; Module name not found
    push rdx ; Sauve le noeud courant
    push rcx ; Sauve le pointeur string "KERNEL32..."
    mov rsi, [rdx + 0x50] ; RSI = Buffer
    mov rdi, rcx
    test rsi, rsi ; Buffer null ?
    jz _next_candidate

_compare_char:
    mov ax, [rsi]
    mov bx, [rdi]
    cmp ax, bx
    jne _next_candidate
    test ax, ax
    jz _found_match
    add rsi, 2
    add rdi, 2
    jmp _compare_char

_next_candidate:
    pop rcx
    pop rdx
    mov rdx, [rdx] ; Avance au suivant (Flink est à offset 0x00)
    jmp _scan_loop

_found_match:
    pop rcx
    pop rax ; RAX = Le noeud courant (qui était dans RDX)
    mov rax, [rax + 0x20] ; Récupère DllBase (0x30 - 0x10)
    ret

_not_found:
    xor rax, rax
    ret

; =============================================================
; get_export_ctx
; Vérifie simplement que le module a un PE Header valide et un EAT.
; IN:  RCX = DllBase
; OUT: RAX = DllBase (Context) ou 0 si invalide
; =============================================================
get_export_ctx:
    mov eax, [rcx + 0x3C]      ; e_lfanew (Offset PE Header)
    add rax, rcx               ; RAX = Adresse PE Header
    
    ; Vérification signature "PE" (Optionnel mais recommandé)
    cmp dword [rax], 0x00004550 ; "PE\0\0"
    jne .fail

    ; Vérification présence Export Directory
    ; Offset 0x88 = DataDirectory[0].VirtualAddress (Export)
    mov edx, [rax + 0x88]      
    test edx, edx
    jz .fail

    mov rax, rcx               ; Succès : On retourne la Base comme Context
    ret
.fail:
    xor rax, rax
    ret

; =============================================================
; resolve_export_by_name
; Trouve une fonction par son nom ASCII dans l'EAT.
; IN:  RCX = DllBase (Context)
; IN:  RDX = Pointeur chaîne ASCII (ex: "GetProcAddress")
; OUT: RAX = Adresse virtuelle (VA) de la fonction ou 0
; =============================================================
resolve_export_by_name:
    push rbx
    push rsi
    push rdi
    push r12 

    mov r8, rcx                ; R8 = DllBase
    mov r9, rdx                ; R9 = Chaîne cible

    ; 1. Accès à l'Export Directory
    mov eax, [r8 + 0x3C]       ; e_lfanew
    add rax, r8                ; PE Header
    mov eax, [rax + 0x88]      ; RVA Export Dir
    add rax, r8                ; RAX = VA Export Dir
    mov r10, rax               ; R10 pointe sur IMAGE_EXPORT_DIRECTORY

    ; 2. Récupération des pointeurs clés
    mov ecx,  [r10 + 0x18]     ; ECX = NumberOfNames (Compteur boucle)
    mov r11d, [r10 + 0x20]     ; RVA AddressOfNames
    add r11, r8                ; R11 = VA AddressOfNames (Tableau de RVA)

    ; 3. Boucle de recherche
    ; On itère de (NumberOfNames-1) jusqu'à 0
.loop_find:
    jecxz .not_found           ; Si compteur = 0 -> Fini
    dec rcx                    ; Index actuel

    ; Récupérer le nom courant
    mov edx, [r11 + rcx*4]     ; RDX = RVA du nom (DWORD)
    add rdx, r8                ; RDX = VA du nom (String ASCII)

    ; Comparaison (RDX vs R9)
    call _strcmp_ascii
    test eax, eax              ; 0 = Match
    jnz .loop_find             ; Pas match ? Suivant

    ; 4. Match trouvé ! Récupérer l'adresse
    ; A) Trouver l'Ordinal
    mov r12d, [r10 + 0x24]     ; RVA AddressOfNameOrdinals
    add r12, r8
    movzx edx, word [r12 + rcx*2] ; EDX = Ordinal (WORD !)

    ; B) Trouver la Fonction
    mov r12d, [r10 + 0x1c]     ; RVA AddressOfFunctions
    add r12, r8
    mov eax, [r12 + rdx*4]     ; RAX = RVA de la fonction
    add rax, r8                ; RAX = VA de la fonction (Adresse finale)
    
    jmp .done

.not_found:
    xor rax, rax

.done:
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

; helper: strcmp (r9=target, rdx=current)
; Modifie RSI/RDI/AL/BL. Preservé par l'appelant.
_strcmp_ascii:
    push rsi
    push rdi
    mov rsi, rdx
    mov rdi, r9
.cmp_loop:
    mov al, byte [rsi]
    mov bl, byte [rdi]
    cmp al, bl
    jne .diff
    test al, al
    jz .match
    inc rsi
    inc rdi
    jmp .cmp_loop
.diff:
    mov eax, 1
    jmp .end_cmp
.match:
    xor eax, eax
.end_cmp:
    pop rdi
    pop rsi
    ret

; =============================================================
; DATA
; =============================================================
w_kernel32:         dw 'K','E','R','N','E','L','3','2','.','D','L','L', 0
a_GetProcAddress:   db 'GetProcAddress', 0
a_GetModuleHandleA: db 'GetModuleHandleA', 0
