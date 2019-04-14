#include <windows.h>
#include <stdlib.h>

#define _CRTALLOC(x) __declspec(allocate(x))

ULONG _tls_index = 0;

#if MSVCRT_VERSION < 140
#pragma section(".tls$AAA")
#pragma section(".tls$ZZZ")
#endif

#pragma section(".CRT$XLA", long, read)
#pragma section(".CRT$XLZ", long, read)
#pragma section(".CRT$XIA", long, read)
#pragma section(".CRT$XIZ", long, read)
#pragma section(".CRT$XCA", long, read)
#pragma section(".CRT$XCZ", long, read)
#pragma section(".CRT$XPA", long, read)
#pragma section(".CRT$XPZ", long, read)
#pragma section(".CRT$XTA", long, read)
#pragma section(".CRT$XTZ", long, read)
#pragma section(".rdata$T", long, read)

#pragma comment(linker, "/merge:.CRT=.rdata")

#if MSVCRT_VERSION >= 140 // UCRT

#pragma data_seg(".tls")
#ifdef _M_X64
_CRTALLOC(".tls")
#endif
char _tls_start = 0;

#pragma data_seg(".tls$ZZZ")
#ifdef _M_X64
_CRTALLOC(".tls$ZZZ")
#endif  /* defined (_M_X64) */
char _tls_end = 0;

#pragma data_seg()

#else // MSVCRT_VERSION < 140

/* TLS raw template data start and end. */
_CRTALLOC(".tls$AAA") int _tls_start = 0;
_CRTALLOC(".tls$ZZZ") int _tls_end = 0;

#endif

// TLS init/exit callbacks
_CRTALLOC(".CRT$XLA") PIMAGE_TLS_CALLBACK __xl_a = 0;
_CRTALLOC(".CRT$XLZ") PIMAGE_TLS_CALLBACK __xl_z = 0;

_CRTALLOC(".rdata$T") const IMAGE_TLS_DIRECTORY _tls_used =
{
  (SIZE_T) &_tls_start,
  (SIZE_T) &_tls_end,
  (SIZE_T) &_tls_index,
  (SIZE_T) (&__xl_a+1),
  (ULONG) 0, // SizeOfZeroFill
  (ULONG) 0 // Characteristics
};

typedef void(*_PVFV)(void);

// C init
_CRTALLOC(".CRT$XIA") _PVFV __xi_a[] = { NULL };
_CRTALLOC(".CRT$XIZ") _PVFV __xi_z[] = { NULL };
// C++ init
_CRTALLOC(".CRT$XCA") _PVFV __xc_a[] = { NULL };
_CRTALLOC(".CRT$XCZ") _PVFV __xc_z[] = { NULL };
// C pre-terminators
_CRTALLOC(".CRT$XPA") _PVFV __xp_a[] = { NULL };
_CRTALLOC(".CRT$XPZ") _PVFV __xp_z[] = { NULL };
// C terminators
_CRTALLOC(".CRT$XTA") _PVFV __xt_a[] = { NULL };
_CRTALLOC(".CRT$XTZ") _PVFV __xt_z[] = { NULL };

int _fltused = 0x9875;

#ifdef _M_IX86
// magic linker symbols available if the binary has a safe exception table
// (implicit if all object files are safe-EH compatible)
extern PVOID __safe_se_handler_table[];
extern BYTE  __safe_se_handler_count;
#endif

const DECLSPEC_SELECTANY IMAGE_LOAD_CONFIG_DIRECTORY _load_config_used =
{
  sizeof(_load_config_used),
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
#ifdef _M_IX86
  (SIZE_T) __safe_se_handler_table,
  (SIZE_T) &__safe_se_handler_count,
#else
  0,
  0,
#endif
  0,
  0,
  0,
  0,
  0,
};
