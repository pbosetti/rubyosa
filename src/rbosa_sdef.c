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
 
    if (criterion == ID2SYM (rb_intern ("signature"))) {
        err = LSFindApplicationForInfo (RVAL2FOURCHAR (value), NULL, NULL, fs_ref, &URL);
        *app_signature = value; /* Don't need to get the app signature, we already have it. */
    }
    else { 
        CFMutableStringRef  str;
        
        str = CFStringCreateMutable (kCFAllocatorDefault, 0);
        CFStringAppendCString (str, RVAL2CSTR (value), kCFStringEncodingUTF8);

        if (criterion == ID2SYM (rb_intern ("path"))) {
            err = FSPathMakeRef ((const UInt8 *)RVAL2CSTR (value), fs_ref, NULL);
            if (err == noErr) {
                URL = CFURLCreateWithFileSystemPath (kCFAllocatorDefault, str, kCFURLPOSIXPathStyle, FALSE);
            }
        }
        else if (criterion == ID2SYM (rb_intern ("name"))) {
            CFStringRef dot_app;
            
            dot_app = CFSTR (".app");
            if (!CFStringHasSuffix (str, dot_app))
                CFStringAppend (str, dot_app);
   
            err = LSFindApplicationForInfo (kLSUnknownCreator, NULL, str, fs_ref, &URL);
            *app_name = value; /* Don't need to get the app name, we already have it. */
        }
        else if (criterion == ID2SYM (rb_intern ("bundle_id"))) {
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

    if (!NIL_P (val)) {
        if (TYPE (val) != T_STRING)
            rb_raise (rb_eArgError, "argument '%s' must have a String value", RVAL2CSTR (sym));
        if (psym != NULL)
            *psym = sym;
    }

    return val;     
}

static OSStatus 
send_simple_remote_event (AEEventClass ec, AEEventID ei, const char *target_url, const AEDesc *dp, AppleEvent *reply)
{
    OSStatus  err;
    AEDesc    target, ev, root_reply;

    if ((err = AECreateDesc ('aprl', target_url, strlen(target_url), &target)) != noErr)
        return err; 

    if ((err = AECreateAppleEvent (ec, ei, &target, kAutoGenerateReturnID, kAnyTransactionID, &ev)) != noErr) {
        AEDisposeDesc (&target);
        return err;
    }

    if (dp != NULL) 
        AEPutParamDesc (&ev, keyDirectObject, dp);

    err = AESend (&ev, &root_reply, kAEWaitReply, kAENormalPriority, kAEDefaultTimeout, NULL, NULL);
    if (err == noErr) 
        err = AEGetParamDesc (&root_reply, keyDirectObject, typeWildCard, reply);

    // XXX we should check for application-level errors

    AEDisposeDesc (&target);
    AEDisposeDesc (&ev);
    AEDisposeDesc (&root_reply);
    
    return err;
}

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
typedef SInt16 ResFileRefNum;
#endif

static VALUE
get_remote_app_sdef (const char *target_url)
{
    AEDesc        zero, reply, aete;
    Size          datasize;
    void *        data;
    int           fd;
    FSRef         fs;
    CFDataRef     sdef_data;
    VALUE         sdef;
    ResFileRefNum res_num;
    Handle        res;
    SInt32        z = 0;
    OSErr         osa_error;
    HFSUniStr255  resourceForkName; 
    char          tmp_res_path[] = "/tmp/FakeXXXXXX.osax";

#define BOOM(m) \
    do { \
        rb_raise (rb_eRuntimeError, \
                  "Can't get scripting definition of remote application (%s) : %s (%d)", \
                  m, error_code_to_string (osa_error), osa_error); \
    } while (0)

    // XXX we should try to get the sdef via ascr/gsdf before trying to convert the AETE!

    AECreateDesc (typeSInt32, &z, sizeof (z), &zero);
    osa_error = send_simple_remote_event ('ascr', 'gdte', target_url, &zero, &reply);    
    AEDisposeDesc (&zero);
    if (osa_error != noErr)
        BOOM ("sending event");

    osa_error = AECoerceDesc (&reply, kAETerminologyExtension, &aete);
    AEDisposeDesc (&reply);
    if (osa_error != noErr)
        BOOM ("coercing result");

    datasize = AEGetDescDataSize (&aete);
    data = (void *)malloc (datasize);
    if (data == NULL)
        BOOM ("cannot allocate memory");

    osa_error = AEGetDescData (&aete, data, datasize);
    AEDisposeDesc (&aete);
    if (osa_error != noErr) {
        free (data);
        BOOM ("get data");
    }

    if (mkstemps (tmp_res_path, 5) == -1) {
        free (data);
        BOOM ("generate resource file name");
    }

    fd = open (tmp_res_path, O_CREAT|O_TRUNC|O_WRONLY, 0644);
    if (fd == -1) {
        free (data);
        BOOM ("creating resource file");
    }
    close (fd);

    FSPathMakeRef ((const UInt8 *)tmp_res_path, &fs, NULL);
    FSGetResourceForkName (&resourceForkName); 
 
    osa_error = FSCreateResourceFork (&fs, resourceForkName.length, resourceForkName.unicode, 0);
    if (osa_error != noErr) {
        free (data);
        BOOM ("creating resource fork");
    }

    osa_error = FSOpenResourceFile (&fs, resourceForkName.length, resourceForkName.unicode, fsRdWrPerm, &res_num);
    if (osa_error != noErr) {
        free (data);
        BOOM ("opening resource fork");
    }

    res = NewHandle (datasize);
    memcpy (*res, data, datasize);
    AddResource (res, 'aete', 0, (ConstStr255Param)"");

    free (data);
    CloseResFile (res_num);

    osa_error = OSACopyScriptingDefinition (&fs, kOSAModeNull, &sdef_data);
    unlink (tmp_res_path);
    if (osa_error != noErr)
        rb_raise (rb_eRuntimeError, "Cannot get scripting definition : error %d", osa_error);

    sdef = rb_str_new ((const char *)CFDataGetBytePtr (sdef_data), 
                       CFDataGetLength (sdef_data));

    CFRelease (sdef_data);

    return sdef;
}

VALUE
rbosa_scripting_info (VALUE self, VALUE hash)
{
    const char *    error;
    VALUE           criterion;
    VALUE           value;
    VALUE           remote;
    char            c_remote[128];
    VALUE           ary;
    VALUE           name;  
    VALUE           signature;
    VALUE           sdef;
    OSAError        osa_error;

    Check_Type (hash, T_HASH);

    criterion = name = signature = Qnil;
    value = __get_criterion (hash, "name", &criterion);
    if (NIL_P (value))
        value = __get_criterion (hash, "path", &criterion);
    if (NIL_P (value))
        value = __get_criterion (hash, "bundle_id", &criterion);
    if (NIL_P (value))
        value = __get_criterion (hash, "signature", &criterion);
    if (NIL_P (value))
        rb_raise (rb_eArgError, "expected :name, :path, :bundle_id or :signature key/value");

    remote = __get_criterion (hash, "machine", NULL);
    if (!NIL_P (remote)) {
        VALUE username;
        VALUE password;

        if (NIL_P (value) || criterion != ID2SYM (rb_intern ("name")))
            rb_raise (rb_eArgError, ":machine argument requires :name");
        name = value;
 
        username = __get_criterion (hash, "username", NULL);
        password = __get_criterion (hash, "password", NULL);

        if (NIL_P (username)) {
            if (!NIL_P (password))
                rb_raise (rb_eArgError, ":password argument requires :username");
            snprintf (c_remote, sizeof c_remote, "eppc://%s/%s", 
                      RVAL2CSTR (remote), RVAL2CSTR (value));
        }
        else {
            if (NIL_P (password))
                snprintf (c_remote, sizeof c_remote, "eppc://%s@%s/%s", 
                          RVAL2CSTR (username), RVAL2CSTR (remote), 
                          RVAL2CSTR (value));
            else
                snprintf (c_remote, sizeof c_remote, "eppc://%s:%s@%s/%s", 
                          RVAL2CSTR (username), RVAL2CSTR (password), 
                          RVAL2CSTR (remote), RVAL2CSTR (value));
        }

        remote = CSTR2RVAL (c_remote);
    } 

    if (RHASH (hash)->tbl->num_entries > 0) {
        VALUE   keys;

        keys = rb_funcall (hash, rb_intern ("keys"), 0);
        rb_raise (rb_eArgError, "inappropriate argument(s): %s", 
                  RSTRING (rb_inspect (keys))->ptr);
    }

    if (NIL_P (remote)) {
        FSRef           fs;
        CFDataRef       sdef_data;
        
        if (!rbosa_translate_app (criterion, value, &signature, &name, &fs, &error))
            rb_raise (rb_eRuntimeError, error);

        osa_error = OSACopyScriptingDefinition (&fs, kOSAModeNull, &sdef_data);
        if (osa_error != noErr)
            rb_raise (rb_eRuntimeError, "Cannot get scripting definition : error %d", osa_error);

        sdef = rb_str_new ((const char *)CFDataGetBytePtr (sdef_data), 
                           CFDataGetLength (sdef_data));

        CFRelease (sdef_data);
    }
    else {
        sdef = get_remote_app_sdef (c_remote);
    }

    ary = rb_ary_new3 (3, name, NIL_P (remote) ? signature : remote, sdef); 

    return ary;
}

VALUE
rbosa_remote_processes (VALUE self, VALUE machine)
{
    char buf[128];
    CFStringRef str;
    CFURLRef url;
    AERemoteProcessResolverRef resolver;
    CFArrayRef cfary; 
    CFStreamError cferr;
    VALUE ary;
    unsigned i, count;

    snprintf (buf, sizeof buf, "eppc://%s", RVAL2CSTR (machine));
    str = CFStringCreateWithCString (kCFAllocatorDefault, buf, kCFStringEncodingUTF8);
    url = CFURLCreateWithString (kCFAllocatorDefault, str, NULL);
    CFRelease (str);
    resolver = AECreateRemoteProcessResolver (kCFAllocatorDefault, url);    
    CFRelease (url);

    cfary = AERemoteProcessResolverGetProcesses (resolver, &cferr); 
    if (cfary == NULL) {
        AEDisposeRemoteProcessResolver (resolver);
        rb_raise (rb_eRuntimeError, "Can't resolve the remote processes on machine '%s' : error %d (domain %d)",
                  RVAL2CSTR (machine), cferr.error, cferr.domain);
    }

    ary = rb_ary_new ();
    for (i = 0, count = CFArrayGetCount (cfary); i < count; i++) {
        CFDictionaryRef dict;
        VALUE hash;
        CFNumberRef number;

        dict = (CFDictionaryRef)CFArrayGetValueAtIndex (cfary, i);
        hash = rb_hash_new ();

        url = CFDictionaryGetValue (dict, kAERemoteProcessURLKey);
        if (url == NULL)
            continue;

        url = CFURLCopyAbsoluteURL (url);
        str = CFURLGetString (url);

        rb_hash_aset (hash, ID2SYM (rb_intern ("url")), CSTR2RVAL (CFStringGetCStringPtr (str, CFStringGetFastestEncoding (str))));

        CFRelease (url);

        str = CFDictionaryGetValue (dict, kAERemoteProcessNameKey);
        if (str == NULL)
            continue;
        
        rb_hash_aset (hash, ID2SYM (rb_intern ("name")), CSTR2RVAL (CFStringGetCStringPtr (str, CFStringGetFastestEncoding (str))));

        number = CFDictionaryGetValue (dict, kAERemoteProcessUserIDKey);
        if (number != NULL) {
            int uid;

            if (CFNumberGetValue (number, kCFNumberIntType, &uid))
                rb_hash_aset (hash, ID2SYM (rb_intern ("uid")), INT2FIX (uid));
        }
        
        number = CFDictionaryGetValue (dict, kAERemoteProcessProcessIDKey);
        if (number != NULL) {
            int pid;

            if (CFNumberGetValue (number, kCFNumberIntType, &pid))
                rb_hash_aset (hash, ID2SYM (rb_intern ("pid")), INT2FIX (pid));
        }

        rb_ary_push (ary, hash);
    }    

    AEDisposeRemoteProcessResolver (resolver);

    return ary;   
}
