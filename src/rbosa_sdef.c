/*
 * Copyright (c) 2006, Apple Computer, Inc. All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
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
#include "rbosa.h"

static VALUE
rbosa_app_signature (CFURLRef URL)
{
    CFBundleRef     bundle;
    CFDictionaryRef info;
    CFStringRef     signature;
    VALUE           rb_signature;

    bundle = CFBundleCreate (kCFAllocatorDefault, URL);
    info = CFBundleGetInfoDictionary (bundle);
    signature = CFDictionaryGetValue (info, CFSTR ("CFBundleSignature"));
    if (signature != NULL) {
        rb_signature = CSTR2RVAL (CFStringGetCStringPtr (signature, CFStringGetFastestEncoding (signature))); 
    }
    else {
        rb_signature = Qnil;
    }
    
    CFRelease (bundle);

    return rb_signature;
}

static bool 
rbosa_translate_app_name (const char *app_name, VALUE *app_signature, FSRef *fs_ref, const char **error)
{
    OSStatus    err;
    CFURLRef    URL;
 
    if (access (app_name, R_OK) != -1) {
        /* Apparently app_name already points to a valid file, let's open it. */
        err = FSPathMakeRef ((const UInt8 *)app_name, fs_ref, NULL);
        if (err == noErr) {
            CFStringRef path;

            path = CFStringCreateWithCString (kCFAllocatorDefault, app_name, kCFStringEncodingUTF8);
            URL = CFURLCreateWithFileSystemPath (kCFAllocatorDefault, path, kCFURLPOSIXPathStyle, FALSE);
            CFRelease (path);
        }
    }
    else {
        /* Mmh not a path, let's ask LaunchServices. */
        CFMutableStringRef str;
        CFStringRef dot_app;

        str = CFStringCreateMutable (kCFAllocatorDefault, 0);
        CFStringAppendCString (str, app_name, kCFStringEncodingUTF8);
        
        dot_app = CFSTR (".app");
        if (!CFStringHasSuffix (str, dot_app))
            CFStringAppend (str, dot_app);

        err = LSFindApplicationForInfo (kLSUnknownCreator, NULL, str, fs_ref, &URL);
    }
    if (err != noErr) {
        *error = "Error when translating the application name";
        return FALSE;
    }

    *app_signature = rbosa_app_signature (URL);
    CFRelease (URL);

    if (*app_signature == Qnil) {
        *error = "Error when getting the application signature";
        return FALSE;
    }
 
    return TRUE;
}

VALUE
rbosa_scripting_info (VALUE self, VALUE app)
{
    const char *    error;
    VALUE           ary;  
    VALUE           signature;
    FSRef           fs;
    OSAError        osa_error;
    CFDataRef       sdef_data;

    if (!rbosa_translate_app_name (RVAL2CSTR (app), &signature, &fs, &error))
        rb_raise (rb_eRuntimeError, error);
 
    osa_error = OSACopyScriptingDefinition (&fs, kOSAModeNull, &sdef_data);
    if (osa_error != noErr)
        rb_raise (rb_eRuntimeError, "Cannot get scripting definition : error %d", osa_error);

    ary = rb_ary_new3 (2, signature, CSTR2RVAL ((const char *)CFDataGetBytePtr (sdef_data)));

    CFRelease (sdef_data);

    return ary;
}
