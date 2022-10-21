#ifndef __DEBUG_H__
#define __DEBUG_H__
#include <stdlib.h>
#include <stdio.h>
static int __debug__;
#define IS_DEBUG()      (__debug__)
#define SET_DEBUG()     do {__debug__ = 1;} while (0)

#define die(...) do {                                   \
                        fprintf(stderr, "[FE ] : ");    \
                        fprintf(stderr, __VA_ARGS__);   \
                        exit(0);                        \
                } while (0)
#define dbg(...)        do {                                            \
                                if(__debug__) {                         \
                                        fprintf(stderr, "[DBG] : ");    \
                                        fprintf(stderr, __VA_ARGS__);   \
                                }                                       \
                        } while (0);

#define ret_err(...)    do {                                    \
                                fprintf(stderr, "[ERR] : ");    \
                                fprintf(stderr, __VA_ARGS__);   \
                                return -1;                      \
                        } while (0);

#define err(...)        do {                                    \
                                fprintf(stderr, "[ERR] : ");    \
                                fprintf(stderr, __VA_ARGS__);   \
                        } while (0);

#define info(...)        do {                                    \
				fprintf(stderr, "[INFO] : ");    \
                                fprintf(stderr, __VA_ARGS__);   \
                        } while (0);

#define fnentry()	dbg("ENTRY : %s\n", __FUNCTION__)
#define fnexit()	dbg("EXIT  : %s\n", __FUNCTION__)
#endif

