/*
 * Copyright (c) 2006-2007, Apple Inc. All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission. 
 * 
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef __RBOSA_H_
#define __RBOSA_H_

#include "osx_ruby.h"
#include <Carbon/Carbon.h>
#include <sys/param.h>

/* rbosa_sdef.c */
VALUE rbosa_scripting_info (VALUE self, VALUE hash);
VALUE rbosa_remote_processes (VALUE self, VALUE machine);

/* rbosa_conv.c */
FourCharCode rbobj_to_fourchar (VALUE obj);
VALUE rbosa_four_char_code (VALUE self, VALUE val);
void rbobj_to_alias_handle (VALUE obj, AliasHandle *alias);

/* rbosa_err.c */
const char *error_code_to_string (const int code);

/* helper macros */
#define RVAL2CSTR(x)        (StringValueCStr (x))
#define CSTR2RVAL(x)        (rb_str_new2 (x))
#define RVAL2CBOOL(x)       (RTEST(x))
#define CBOOL2RVAL(x)       (x ? Qtrue : Qfalse)
#define RVAL2FOURCHAR(x)    (rbobj_to_fourchar(x))

#endif /* __RBOSA_H_ */
