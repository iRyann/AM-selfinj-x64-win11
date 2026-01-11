[bits 64]

; shellcode.nasm - Windows x64
; Author : Ryan Bouchou
; Date : 2026-01-11
; Version : 0
; Description : Minimal stub for GetModuleHnadle and
; GetProcAddress resolution

section .text:
  global _start

_start:

_getAddressKernel32Dll:
; Thanks to PEB Walk method, and assuming that
; kernel32.dll is the third element of the InMemoryOrderList
; we compute the base address of kernel32.dll in r8

  mov rbx, gs:[0x60] ; Get address of PEB struct
  ; According to "Data structure alignment" requirement
  ; We've to consider a 4 bytes spacing between
  ; Reserved[2] and Reserved[3]
  mov rbx, [rbx + 0x18] ; Get address of PEB_LDR_DATA
  add rbx, 0x20 ; Get address of InMemoryOrderModuleList
  mov rbx, [rbx] ; Get the current proc entry
  mov rbx, [rbx] ; Get the ntdll entry
  mov rbx, [rbx] ; Get the kernel32 entry
  mov r8, [rbx + 0x20] ; Get ketnel32.dll base address

_getAddressEAT:
  mov ebx, [r8 + 0x3c] ; Get e_lfanew = PE Header RVA
  add rbx, r8 ; rbx <- e_lfanew + kernel32 base address
