/* Heap guards for the AC-2 firmware, linked with
 * -Wl,--wrap=malloc,--wrap=calloc,--wrap=realloc,--wrap=_Znwj,--wrap=_Znaj.
 * Any call prints the wrapped name and ends the run with exit code 99. With --gc-sections a
 * wrapper that nothing references is dropped, so `nm` on the image shows which were reachable. */
#include <stddef.h>

#include "semihost.h"

static void heap_called(char const* name) __attribute__((noreturn));

static void heap_called(char const* name) {
  sh_write("WRAP: ");
  sh_write(name);
  sh_write(" called (wrapper_calls=1)\n");
  sh_exit(99);
}

void* __wrap_malloc(size_t n) {
  (void)n;
  heap_called("malloc");
}

void* __wrap_calloc(size_t count, size_t n) {
  (void)count;
  (void)n;
  heap_called("calloc");
}

void* __wrap_realloc(void* p, size_t n) {
  (void)p;
  (void)n;
  heap_called("realloc");
}

/* operator new(unsigned int) and operator new[](unsigned int) */
void* __wrap__Znwj(size_t n) {
  (void)n;
  heap_called("operator new");
}

void* __wrap__Znaj(size_t n) {
  (void)n;
  heap_called("operator new[]");
}
