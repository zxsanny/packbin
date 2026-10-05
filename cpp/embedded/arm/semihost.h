/* ARM semihosting calls used by the firmware images (QEMU -semihosting). */
#ifndef PACKBIN_EMBEDDED_SEMIHOST_H
#define PACKBIN_EMBEDDED_SEMIHOST_H

#ifdef __cplusplus
extern "C" {
#endif

/* Writes a NUL-terminated string to the host console. */
void sh_write(char const* text);
/* Writes an unsigned number in decimal. */
void sh_write_uint(unsigned long value);
/* Ends the QEMU run; the process exit code is `code` (0..255). */
void sh_exit(int code) __attribute__((noreturn));

#ifdef __cplusplus
}
#endif

#endif
