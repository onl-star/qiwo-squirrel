/*
 * Shim header for _stdbool types used by Qiwo but not in standard librime headers.
 */
#ifndef QIWO_RIME_SHIM_H_
#define QIWO_RIME_SHIM_H_

#include <rime_api.h>

typedef RimeApi      RimeApi_stdbool;
typedef RimeContext  RimeContext_stdbool;
typedef RimeStatus   RimeStatus_stdbool;

#endif
