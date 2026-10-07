/* One RAM region holds code, constants and data; the host maps it read-write-execute at
 * 0x20000000 and zero-fills what the image does not cover (.bss, the stack). */
MEMORY { RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 1M }
SECTIONS {
  .text : { *(.text*) *(.rodata*) } > RAM
  .data : { *(.data*) } > RAM
  .bss  : { *(.bss*) *(COMMON) } > RAM
  /DISCARD/ : { *(.ARM.exidx*) *(.comment) }
}
