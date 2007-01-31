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

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <unistd.h>
#include <st.h>
#include "rbosa.h"

static void 
rbosa_app_name_signature (CFURLRef URL, VALUE *name, VALUE *signature)
{
    CFBundleRef     bundle;
    CFDictionaryRef info;
    CFStringRef     str;

    bundle = CFBundleCreate (kCFAllocatorDefault, URL);
    info = CFBundleGetInfoDictionary (bundle);
    
    if (NIL_P(*name)) {
        str = CFDictionaryGetValue (info, CFSTR ("CFBundleName"));
        if (str == NULL) {
            /* Try 'CFBundleExecutable' if 'CFBundleName' does not exist (which is a bug). */
            str = CFDictionaryGetValue (info, CFSTR ("CFBundleExecutable"));
        }
        *name = str != NULL ? CSTR2RVAL (CFStringGetCStringPtr (str, CFStringGetFastestEncoding (str))) : Qnil;
    }
    if (NIL_P(*signature)) {
        str = CFDictionaryGetValue (info, CFSTR ("CFBundleSignature"));
        *signature = str != NULL ? CSTR2RVAL (CFStringGetCStringPtr (str, CFStringGetFastestEncoding (str))) : Qnil;
    }

    CFRelease (bundle);
}

static bool 
rbosa_translate_app (VALUE criterion, VALUE value, VALUE *app_signature, VALUE *app_name, FSRef *fs_ref, const char **error)
{
    OSStatus    err;
    CFURLRef    URL;

    *app_name = Qnil;
    *app_signature = Qnil;
    err = noErr;
 
    if (criterion == ID2SYM (rb_intern ("by_signature"))) {
        err = LSFindApplicationForInfo (RVAL2FOURCHAR (value), NULL, NULL, fs_ref, &URL);
        *app_signature = value; /* Don't need to get the app signature, we already have it. */
    }
    else { 
        CFMutableStringRef  str;
        
        str = CFStringCreateMutable (kCFAllocatorDefault, 0);
        CFStringAppendCString (str, RVAL2CSTR (value), kCFStringEncodingUTF8);

        if (criterion == ID2SYM (rb_intern ("by_path"))) {
            err = FSPathMakeRef ((const UInt8 *)RVAL2CSTR (value), fs_ref, NULL);
            if (err == noErr) {
                URL = CFURLCreateWithFileSystemPath (kCFAllocatorDefault, str, kCFURLPOSIXPathStyle, FALSE);
            }
        }
        else if (criterion == ID2SYM (rb_intern ("by_name"))) {
            CFStringRef dot_app;
            
            dot_app = CFSTR (".app");
            if (!CFStringHasSuffix (str, dot_app))
                CFStringAppend (str, dot_app);
   
            err = LSFindApplicationForInfo (kLSUnknownCreator, NULL, str, fs_ref, &URL);
            *app_name = value; /* Don't need to get the app name, we already have it. */
        }
        else if (criterion == ID2SYM (rb_intern ("by_bundle_id"))) {
            err = LSFindApplicationForInfo (kLSUnknownCreator, str, NULL, fs_ref, &URL);
        }
        else {
            *error = "Invalid criterion";
            CFRelease (str);
            return FALSE;
        }
        
        CFRelease (str);
    }
    
    if (err != noErr) {
        *error = "Can't locate the target bundle on the file system";
        return FALSE;
    }

    rbosa_app_name_signature (URL, app_name, app_signature);
    
    CFRelease (URL);

    if (NIL_P (*app_signature)) {
        *error = "Can't get the target bundle signature";
        return FALSE;
    }
 
    return TRUE;
}

static inline VALUE
__get_criterion (VALUE hash, const char *str, VALUE *psym)
{
    VALUE   sym;
    VALUE   val;

    sym = ID2SYM (rb_intern (str));
    val = rb_hash_delete (hash, sym);

    if (!NIL_P (val))
        *psym = sym;

    return val;     
}

VALUE
rbosa_scripting_info (VALUE self, VALUE hash)
{
    const char *    error;
    VALUE           criterion;
    VALUE           value;
    VALUE           ary;
    VALUE           name;  
    VALUE           signature;
    FSRef           fs;
    OSAError        osa_error;
    CFDataRef       sdef_data;

    Check_Type (hash, T_HASH);

    value = __get_criterion (hash, "by_name", &criterion);
    if (NIL_P (value))
        value = __get_criterion (hash, "by_path", &criterion);
    if (NIL_P (value))
        value = __get_criterion (hash, "by_bundle_id", &criterion);
    if (NIL_P (value))
        value = __get_criterion (hash, "by_signature", &criterion);
    if (NIL_P (value))
        rb_raise (rb_eArgError, "expected :by_name, :by_path, :by_bundle_id or :by_signature key/value");

    if (RHASH (hash)->tbl->num_entries > 0) {
        VALUE   keys;

        keys = rb_funcall (hash, rb_intern ("keys"), 0);
        rb_raise (rb_eArgError, "inappropriate argument(s): %s", RSTRING (rb_inspect (keys))->ptr);
    }

    if (!rbosa_translate_app (criterion, value, &signature, &name, &fs, &error))
        rb_raise (rb_eRuntimeError, error);
 
    osa_error = OSACopyScriptingDefinition (&fs, kOSAModeNull, &sdef_data);
    if (osa_error != noErr)
        rb_raise (rb_eRuntimeError, "Cannot get scripting definition : error %d", osa_error);

    ary = rb_ary_new3 (3, name, signature, 
                       rb_str_new ((const char *)CFDataGetBytePtr (sdef_data), 
                                   CFDataGetLength (sdef_data)));

    CFRelease (sdef_data);

    return ary;
}
