/* Minimal Cortex-M startup for the QEMU mps2-an385 / mps2-an386 machines: vector table, .data
 * copy, .bss clear, static constructors, main, then a semihosting exit whose code is main's
 * return value. */
#include <stdint.h>

#include "semihost.h"

extern uint32_t _sidata, _sdata, _edata, _sbss, _ebss, __stack_top;
extern int main(void);
extern void __libc_init_array(void);
/* Present only when the image links librdimon (the vector runner uses newlib stdio). */
extern void initialise_monitor_handles(void) __attribute__((weak));

void Reset_Handler(void) __attribute__((noreturn));
void Fault_Handler(void) __attribute__((noreturn));

/* newlib's __libc_init_array calls these; crti.o is not linked (-nostartfiles). */
void _init(void) {}
void _fini(void) {}

static uint32_t semihost(uint32_t op, void const* arg) {
  register uint32_t r0 __asm__("r0") = op;
  register void const* r1 __asm__("r1") = arg;
  __asm__ volatile("bkpt 0xab" : "+r"(r0) : "r"(r1) : "memory");
  return r0;
}

void sh_write(char const* text) { (void)semihost(0x04u /* SYS_WRITE0 */, text); }

void sh_write_uint(unsigned long value) {
  char buf[24];
  char* p = buf + sizeof(buf) - 1;
  *p = '\0';
  do {
    *--p = (char)('0' + (value % 10u));
    value /= 10u;
  } while (value != 0u);
  sh_write(p);
}

void sh_exit(int code) {
  /* SYS_EXIT_EXTENDED with ADP_Stopped_ApplicationExit carries the exit code to QEMU. */
  uint32_t block[2] = {0x20026u, (uint32_t)code};
  (void)semihost(0x20u, block);
  for (;;) {
  }
}

void Fault_Handler(void) {
  sh_write("FAULT: hard fault on the target\n");
  sh_exit(120);
}

void Reset_Handler(void) {
#if defined(__ARM_FP)
  /* Hard-float images: enable CP10/CP11 before the first FPU instruction. */
  volatile uint32_t* cpacr = (volatile uint32_t*)0xE000ED88u;
  *cpacr |= 0xFu << 20;
  __asm__ volatile("dsb\n\tisb" ::: "memory");
#endif
  uint32_t const* src = &_sidata;
  for (uint32_t* dst = &_sdata; dst < &_edata;)
    *dst++ = *src++;
  for (uint32_t* dst = &_sbss; dst < &_ebss;)
    *dst++ = 0u;
  if (initialise_monitor_handles)
    initialise_monitor_handles();
  __libc_init_array();
  sh_exit(main());
}

__attribute__((section(".isr_vector"), used)) static void (*const vectors[16])(void) = {
    (void (*)(void))(&__stack_top),
    Reset_Handler,
    Fault_Handler, /* NMI */
    Fault_Handler, /* HardFault */
    Fault_Handler, /* MemManage */
    Fault_Handler, /* BusFault */
    Fault_Handler, /* UsageFault */
    0, 0, 0, 0,
    Fault_Handler, /* SVC */
    Fault_Handler, /* DebugMon */
    0,
    Fault_Handler, /* PendSV */
    Fault_Handler, /* SysTick */
};
