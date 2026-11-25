/* ARM EABI entry point for a freestanding link against Kindle's glibc. */
.syntax unified
.arch armv7-a
.fpu vfpv3
.eabi_attribute 28, 1
.text
.align 2
.global _start
.type _start,%function
_start:
    /* The dynamic linker supplies rtld_fini in r0; argc/argv are on the stack. */
    mov r6, r0
    mov r5, sp
    ldr r1, [r5]
    add r2, r5, #4
    ldr r0, =main
    mov r3, #0
    /* __libc_start_main(main, argc, argv, init, fini, rtld_fini, stack_end). */
    sub sp, sp, #16
    mov r4, #0
    str r4, [sp, #0]
    str r6, [sp, #4]
    str r5, [sp, #8]
    str r4, [sp, #12]
    bl __libc_start_main
    mov r7, #1
    mov r0, #127
    svc #0
.size _start, .-_start
.section .note.GNU-stack,"",%progbits
