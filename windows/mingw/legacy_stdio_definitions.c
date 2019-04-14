// VS 2015+ defines the printf/scanf function families inline.

#if _MSC_VER < 1900
#error Requires Visual C++ 2015 or newer
#endif

#include <stdio.h>

void __legacy_stdio_definitions()
{
    fprintf(NULL, NULL);
    fscanf(NULL, NULL);
    fwprintf(NULL, NULL);
    fwscanf(NULL, NULL);
    printf(NULL);
    scanf(NULL);
    snprintf(NULL, 0, NULL);
    sprintf(NULL, NULL);
    sscanf(NULL, NULL);
    swprintf(NULL, 0, NULL);
    swscanf(NULL, NULL);
    vfprintf(NULL, NULL, NULL);
    vfscanf(NULL, NULL, NULL);
    vfwprintf(NULL, NULL, NULL);
    vfwscanf(NULL, NULL, NULL);
    vprintf(NULL, NULL);
    vscanf(NULL, NULL);
    vsnprintf(NULL, 0, NULL, NULL);
    vsprintf(NULL, NULL, NULL);
    vsscanf(NULL, NULL, NULL);
    vswprintf(NULL, 0, NULL, NULL);
    vswscanf(NULL, NULL, NULL);
    vwprintf(NULL, NULL);
    vwscanf(NULL, NULL);
    wprintf(NULL);
    wscanf(NULL);
}
