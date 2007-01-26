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

#include "rbosa.h"

FourCharCode
rbobj_to_fourchar (VALUE obj)
{
    FourCharCode result = 0;

#define USAGE_MSG "requires 4 length size string/symbol or integer"

    if (rb_obj_is_kind_of (obj, rb_cInteger)) {
        result = NUM2UINT (obj);
    }
    else {
        if (rb_obj_is_kind_of (obj, rb_cSymbol))
            obj = rb_obj_as_string (obj);

        if (rb_obj_is_kind_of (obj, rb_cString)) {
            if (RSTRING (obj)->len != 4)
                rb_raise (rb_eArgError, USAGE_MSG);
            result = *(FourCharCode*)(RSTRING (obj)->ptr);
            result = CFSwapInt32HostToBig (result);
        }
        else {
            rb_raise (rb_eArgError, USAGE_MSG);
        }
    }

#undef USAGE_MSG

    return result;
}

VALUE
rbosa_four_char_code (VALUE self, VALUE val)
{
    return INT2NUM (RVAL2FOURCHAR (val));
}

void
rbobj_to_alias_handle (VALUE obj, AliasHandle *alias)
{
    FSRef       ref;
    CFURLRef    URL;
    Boolean     ok;
    OSErr       error;

    Check_Type (obj, T_STRING);
    *alias = NULL;

    URL = CFURLCreateFromFileSystemRepresentation (kCFAllocatorDefault, 
                                                   (const UInt8 *)RSTRING (obj)->ptr, 
                                                   RSTRING (obj)->len,
                                                   0 /* XXX: normally passing 0 even if it's a directory should
                                                        not hurt, as we are just getting the FSRef. */); 
    if (URL == NULL)
        rb_raise (rb_eArgError, "Invalid path given");
    ok = CFURLGetFSRef (URL, &ref);
    CFRelease (URL);
    if (ok) {
        error = FSNewAlias (NULL, &ref, alias);
        if (error != noErr)
            rb_raise (rb_eArgError, "Cannot create alias handle for given filename '%s' : %s (%d)",
                      RSTRING (obj)->ptr, GetMacOSStatusErrorString (error), error); 
    }
    else {
        rb_raise (rb_eArgError, "Cannot obtain the filesystem reference for given filename '%s'",
                  RSTRING (obj)->ptr);
    }
}
