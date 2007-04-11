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
#include <st.h>

static VALUE mOSA;
static VALUE cOSAElement;
static VALUE cOSAElementList;
static VALUE cOSAElementRecord;
static VALUE mOSAEventDispatcher;

static ID sClasses;
static ID sApp;

static void
rbosa_element_free (void *ptr)
{
    AEDisposeDesc (ptr);
    free (ptr);
}

static VALUE
__rbosa_class_from_desc_data (VALUE app, AEDesc res)
{
    DescType    data;
    Size        datasize;
    VALUE       classes, klass; 
 
    classes = rb_ivar_get (app, sClasses);
    if (NIL_P (classes))
        return Qnil;
    klass = Qnil;

    datasize = AEGetDescDataSize (&res);
    /* This should always be a four-byte code. */
    if (datasize != sizeof (DescType))
        return Qnil;

    if (AEGetDescData (&res, &data, datasize) == noErr) {
        char dtStr[5];
        
        *(DescType *)dtStr = CFSwapInt32HostToBig (data);
        klass = rb_hash_aref (classes, rb_str_new (dtStr, 4));
    }

    return klass;
}

static VALUE
rbosa_element_make (VALUE klass, AEDesc *desc, VALUE app)
{
    AEDesc *    newDesc;
    VALUE       new_klass, obj;

    newDesc = (AEDesc *)malloc (sizeof (AEDesc));
    if (newDesc == NULL)
        rb_fatal ("cannot allocate memory");
    memcpy (newDesc, desc, sizeof (AEDesc));
    new_klass = Qnil;

    /* Let's replace the klass here according to the type of the descriptor,
     * if the basic class OSA::Element was given.
     */
    if (klass == cOSAElement) {
        if (newDesc->descriptorType == 'list') {
            klass = cOSAElementList;
        }
        else if (newDesc->descriptorType == 'reco') {
            klass = cOSAElementRecord;
        }
        else if (newDesc->descriptorType == 'type') {
            new_klass = __rbosa_class_from_desc_data (app, *newDesc);
        }
        else if (newDesc->descriptorType == 'obj ' && !NIL_P (app)) {
            AEDesc  res;
            OSErr   err;

            if ((err = AEGetParamDesc ((AppleEvent *)newDesc, 'want', '****', &res)) == noErr)
                new_klass = __rbosa_class_from_desc_data (app, res);
        }
    }

    if (!NIL_P (new_klass))
        klass = new_klass; 
    
    obj = Data_Wrap_Struct (klass, NULL, rbosa_element_free, newDesc);

    rb_ivar_set (obj, sApp, NIL_P (app) ? obj : app);

    return obj;
}

static AEDesc *
rbosa_element_aedesc (VALUE element)
{
    AEDesc *    desc;

    if (!rb_obj_is_kind_of (element, cOSAElement))
        rb_raise (rb_eArgError, "Invalid argument of type '%s' (required: OSA::Element)", rb_class2name (rb_class_of (element)));

    Data_Get_Struct (element, AEDesc, desc);
 
    return desc;
}

static VALUE
rbosa_element_new (VALUE self, VALUE type, VALUE value)
{
    FourCharCode    ffc_type;
    OSErr           error;
    const char *    c_value;
    unsigned        c_value_size;
    AEDesc          desc;

    ffc_type = RVAL2FOURCHAR (type);

    if (NIL_P (value)) {
        c_value = NULL;
        c_value_size = 0;
    }
    else if (rb_obj_is_kind_of (value, rb_cInteger)) {
        FourCharCode code;

        code = NUM2INT (value);
        c_value = (const char *)&code;
        c_value_size = sizeof (FourCharCode);
    }  
    else if (ffc_type == 'alis') {
        AliasHandle     alias;

        rbobj_to_alias_handle (value, &alias);
        
        c_value = (const char *)*alias;
        c_value_size = GetHandleSize ((Handle)alias);
    }
    else {
        Check_Type (value, T_STRING);
        c_value = RSTRING (value)->ptr;
        c_value_size = RSTRING (value)->len;
    }

    error = AECreateDesc (ffc_type, c_value, c_value_size, &desc);
    if (error != noErr)     
        rb_raise (rb_eArgError, "Cannot create Apple Event descriptor from type '%s' value '%s' : %s (%d)", 
                  RVAL2CSTR (type), c_value, error_code_to_string (error), error);

    return rbosa_element_make (self, &desc, Qnil);
}

static VALUE
rbosa_element_new_os (VALUE self, VALUE desired_class, VALUE container, VALUE key_form, VALUE key_data)
{
    OSErr   error;
    AEDesc  obj_specifier;   

    error = CreateObjSpecifier (RVAL2FOURCHAR (desired_class),
                                rbosa_element_aedesc (container),
                                RVAL2FOURCHAR (key_form),
                                rbosa_element_aedesc (key_data),
                                false,
                                &obj_specifier);

    if (error != noErr) 
        rb_raise (rb_eArgError, "Cannot create Apple Event object specifier for desired class '%s' : %s (%d)", 
                  RVAL2CSTR (desired_class), error_code_to_string (error), error);

    return rbosa_element_make (self, &obj_specifier, Qnil);
}

static VALUE
rbosa_element_dup (VALUE self, VALUE element)
{
    AEDesc *  desc;
    AEDesc    new_desc;
    OSErr     error;

    desc = rbosa_element_aedesc (element);
    error = AEDuplicateDesc (desc, &new_desc);
    if (error != noErr) 
        rb_raise (rb_eArgError, "Cannot duplicate element : %s (%d)", 
                  error_code_to_string (error), error);

    return rbosa_element_make (self, &new_desc, Qnil); 
}

static void
__rbosa_raise_potential_app_error (AEDesc *reply)
{
    OSErr   error;
    AEDesc  errorNumDesc;
    AEDesc  errorStringDesc;
    int     errorNum;
    const char *  errorMsg;
    char    exception[128];

    if (AEGetParamDesc (reply, keyErrorNumber, typeSInt32, &errorNumDesc) != noErr)
        return; 

    if (AEGetDescData (&errorNumDesc, &errorNum, sizeof errorNum) != noErr) {
        AEDisposeDesc (&errorNumDesc);
        return;
    }

    /* The reply is an application error. */

    errorMsg = error_code_to_string(errorNum);
    if (errorMsg == NULL)
        errorMsg = "Unknown error";

    exception[0] = '\0';
    error = AEGetParamDesc (reply, keyErrorString, typeChar, &errorStringDesc);
    if (error == noErr) {
        Size size;

        size = AEGetDescDataSize (&errorStringDesc);
        if (size > 0) {
            char *msg;

            msg = (char *)malloc (size + 1);
            if (msg != NULL) {
                if (AEGetDescData (&errorStringDesc, msg, size) == noErr) {
                    msg[size] = '\0';
                    snprintf (exception, sizeof exception, "application returned error: %s (%d), with message: %s", errorMsg, errorNum, msg);
                }
                free (msg);
            }
        }
        AEDisposeDesc (&errorStringDesc);
    }

    if (exception[0] == '\0')
        snprintf (exception, sizeof exception, "application returned error: %s (%d)", errorMsg, errorNum);

    AEDisposeDesc (&errorNumDesc);

    rb_raise (rb_eRuntimeError, exception);
}

static VALUE
rbosa_app_send_event (VALUE self, VALUE event_class, VALUE event_id, VALUE params, VALUE need_retval)
{
    OSErr       error;
    AppleEvent  ae;
    AppleEvent  reply;
    VALUE       rb_timeout;
    SInt32      timeout;
    VALUE       rb_reply;
    unsigned    has_direct_param;

    error = AECreateAppleEvent (RVAL2FOURCHAR (event_class),
                                RVAL2FOURCHAR (event_id),
                                rbosa_element_aedesc (self),
                                kAutoGenerateReturnID,
                                kAnyTransactionID,
                                &ae);
    if (error != noErr)
        rb_raise (rb_eArgError, "Cannot create Apple Event '%s%s' : %s (%d)", 
                  RVAL2CSTR (event_class), RVAL2CSTR (event_id), error_code_to_string (error), error);

    has_direct_param = 0;
    if (!NIL_P (params)) {
        unsigned    i;

        for (i = 0; i < RARRAY (params)->len; i++) {
            VALUE   ary;
            VALUE   type;
            VALUE   element;
            FourCharCode code;

            ary = RARRAY (params)->ptr[i];
            if (NIL_P (ary) || RARRAY (ary)->len != 2)
                continue;

            type = RARRAY (ary)->ptr[0];
            element = RARRAY (ary)->ptr[1];
            code = RVAL2FOURCHAR (type);

            if (code == '----')
                has_direct_param = 1;

            error = AEPutParamDesc (&ae, RVAL2FOURCHAR (type), rbosa_element_aedesc (element));
            if (error != noErr) { 
                AEDisposeDesc (&ae); 
                rb_raise (rb_eArgError, "Cannot add Apple Event parameter '%s' : %s (%d)", 
                          RVAL2CSTR (type), error_code_to_string (error), error);
            }
        } 
    }

    rb_timeout = rb_iv_get (mOSA, "@timeout");
    timeout = NIL_P (rb_timeout) ? kAEDefaultTimeout : NUM2INT (rb_timeout);

    if (has_direct_param == 0)
        AEPutAttributePtr (&ae, 'subj', typeNull, NULL, 0);

    error = AESend (&ae, &reply, (RVAL2CBOOL(need_retval) ? kAEWaitReply : kAENoReply) | kAECanInteract | kAECanSwitchLayer,
                    kAENormalPriority, timeout, NULL, NULL);

    AEDisposeDesc (&ae); 

    if (error != noErr)
        rb_raise (rb_eRuntimeError, "Cannot send Apple Event '%s%s' : %s (%d)", 
                  RVAL2CSTR (event_class), RVAL2CSTR (event_id), error_code_to_string (error), error);

    __rbosa_raise_potential_app_error (&reply);

    if (RTEST (need_retval)) {
        AEDesc  replyObject;

        AEGetParamDesc (&reply, keyDirectObject, typeWildCard, &replyObject);

        rb_reply = rbosa_element_make (cOSAElement, &replyObject, self);
    }
    else {
        rb_reply = Qnil;
    }

    AEDisposeDesc (&reply);
        
    return rb_reply;
}

static VALUE
rbosa_element_type (VALUE self)
{
    AEDesc  *desc;
    char    dtStr[5];

    desc = rbosa_element_aedesc (self);
    *(DescType*)dtStr = CFSwapInt32HostToBig (desc->descriptorType);

    return rb_str_new (dtStr, 4);
}

static VALUE
rbosa_element_data (int argc, VALUE *argv, VALUE self)
{
    VALUE       coerce_type;
    AEDesc      coerced_desc;
    AEDesc *    desc;
    OSErr       error;
    void *      data;
    Size        datasize;
    VALUE       retval;
    bool        to_4cc;

    rb_scan_args (argc, argv, "01", &coerce_type);
    to_4cc = false;

    desc  = rbosa_element_aedesc (self);
    
    if (!NIL_P (coerce_type)) {
        FourCharCode code;

        code = RVAL2FOURCHAR (coerce_type);
        error = AECoerceDesc (desc, code, &coerced_desc);
        if (error != noErr)
            rb_raise (rb_eRuntimeError, "Cannot coerce desc to type %s : %s (%d)", 
                      RVAL2CSTR (coerce_type), error_code_to_string (error), error);
        
        desc = &coerced_desc;
        to_4cc = code == 'type';
    }

    datasize = AEGetDescDataSize (desc);
    data = (void *)malloc (datasize);
    if (data == NULL) 
        rb_fatal ("cannot allocate memory");
 
    error = AEGetDescData (desc, data, datasize);
    if (error == noErr) {
        if (to_4cc)
            *(DescType*)data = CFSwapInt32HostToBig (*(DescType*)data);
        retval = rb_str_new (data, datasize);
    }
    else {
        retval = Qnil;
    }

    if (!NIL_P (coerce_type))
        AEDisposeDesc (&coerced_desc); 
    free (data);

    if (error != noErr)
        rb_raise (rb_eRuntimeError, "Cannot get desc data : %s (%d)", 
                  error_code_to_string (error), error);
    
    return retval; 
}

static VALUE
__rbosa_insertion_loc_new (VALUE rcv, FourCharCode code)
{
    AEDesc *  self_desc;
    AEDesc    rec;
    AEDesc    pos_desc;
    AEDesc    new_desc;

    self_desc = rbosa_element_aedesc (rcv);
    AECreateList (NULL, 0, true, &rec);
    AEPutParamDesc (&rec, keyAEObject, self_desc);
    AECreateDesc (code, NULL, 0, &pos_desc);
    AEPutParamPtr (&rec, keyAEPosition, typeEnumerated, &pos_desc, 4);
    AECoerceDesc (&rec, typeInsertionLoc, &new_desc);
    AEDisposeDesc (&rec);

    return rbosa_element_make (cOSAElement, &new_desc, Qnil);
}

static VALUE
rbosa_element_after (VALUE self)
{
    return __rbosa_insertion_loc_new (self, kAEAfter); 
}

static VALUE
rbosa_element_before (VALUE self)
{
    return __rbosa_insertion_loc_new (self, kAEBefore);
}

static VALUE
rbosa_element_eql (VALUE self, VALUE other)
{
    AEDesc *    self_desc;
    AEDesc *    other_desc; 
    Size        data_size;
    void *      self_data;
    void *      other_data;
    OSErr       error;
    Boolean     ok;

    if (!rb_obj_is_kind_of (other, rb_class_real (rb_class_of (self))))
        return Qfalse;

    self_desc = rbosa_element_aedesc (self);
    other_desc = rbosa_element_aedesc (other);

    if (self_desc == other_desc)
        return Qtrue;

    if (self_desc->descriptorType != other_desc->descriptorType)
        return Qfalse;

    data_size = AEGetDescDataSize (self_desc);
    if (data_size != AEGetDescDataSize (other_desc))
        return Qfalse;
  
    self_data = (void *)malloc (data_size);
    other_data = (void *)malloc (data_size);  
    ok = 0;

    if (self_data == NULL || other_data == NULL)
        rb_fatal ("cannot allocate memory");

    error = AEGetDescData (self_desc, self_data, data_size);
    if (error != noErr)
        goto bails;

    error = AEGetDescData (other_desc, other_data, data_size);
    if (error != noErr)
        goto bails;
    
    ok = memcmp (self_data, other_data, data_size) == 0;

bails:
    free (self_data);
    free (other_data);

    return CBOOL2RVAL (ok);
}

static VALUE
rbosa_element_inspect (VALUE self)
{
    Handle  h;
    char    buf[1024];

    if (AEPrintDescToHandle (rbosa_element_aedesc (self), &h) != noErr) {
      snprintf (buf, sizeof buf, "<%s:%p>", rb_obj_classname (self), (void *)self);
    }
    else {
      snprintf (buf, sizeof buf, "<%s:%p desc=\"%s\">", rb_obj_classname (self), (void *)self, *h);
      DisposeHandle (h);
    }
    
    return CSTR2RVAL (buf);
}

static long
__rbosa_elementlist_count (AEDescList *list)
{
    OSErr   error;
    long    count;

    error = AECountItems (list, &count);
    if (error != noErr)
        rb_raise (rb_eRuntimeError, "Cannot count items : %s (%d)", 
                  error_code_to_string (error), error);

    return count;
}

static void
__rbosa_elementlist_add (AEDescList *list, VALUE element, long pos)
{
    OSErr   error;

    error = AEPutDesc (list, pos, rbosa_element_aedesc (element));
    if (error != noErr)
        rb_raise (rb_eRuntimeError, "Cannot add given descriptor : %s (%d)", 
                  error_code_to_string (error), error);
}

static VALUE
rbosa_elementlist_new (int argc, VALUE *argv, VALUE self)
{
    OSErr           error;
    AEDescList      list;
    VALUE           ary;
    int             i;

    rb_scan_args (argc, argv, "01", &ary);

    if (!NIL_P (ary))
        Check_Type (ary, T_ARRAY);

    error = AECreateList (NULL, 0, false, &list);
    if (error != noErr) 
        rb_raise (rb_eRuntimeError, "Cannot create Apple Event descriptor list : %s (%d)", 
                  error_code_to_string (error), error);

    if (!NIL_P (ary)) {
        for (i = 0; i < RARRAY (ary)->len; i++)
            __rbosa_elementlist_add (&list, RARRAY (ary)->ptr[i], i + 1); 
    }
    
    return rbosa_element_make (self, &list, Qnil);
}

static VALUE
rbosa_elementlist_add (VALUE self, VALUE element)
{
    AEDescList *    list;

    list = (AEDescList *)rbosa_element_aedesc (self); 
    __rbosa_elementlist_add (list, __rbosa_elementlist_count (list) + 1, element);

    return self;    
}

static VALUE
__rbosa_elementlist_get (VALUE self, long index, AEKeyword *keyword)
{
    OSErr       error;
    AEDesc      desc;

    error = AEGetNthDesc ((AEDescList *)rbosa_element_aedesc (self),
                          index + 1,
                          typeWildCard,
                          keyword,
                          &desc);
    
    if (error != noErr)
        rb_raise (rb_eRuntimeError, "Cannot get desc at index %d : %s (%d)", 
                  index, error_code_to_string (error), error);

    return rbosa_element_make (cOSAElement, &desc, rb_ivar_get (self, sApp));
}

static VALUE
rbosa_elementlist_get (VALUE self, VALUE index)
{
    AEKeyword   keyword;
    return __rbosa_elementlist_get (self, FIX2INT (index), &keyword);
}

static VALUE
rbosa_elementlist_size (VALUE self)
{
    return INT2FIX (__rbosa_elementlist_count ((AEDescList *)rbosa_element_aedesc (self)));
}

static int
__rbosa_elementrecord_set (VALUE key, VALUE value, AEDescList *list)
{
    OSErr       error;

    error = AEPutKeyDesc (list, RVAL2FOURCHAR (key), rbosa_element_aedesc (value));
    if (error != noErr) 
        rb_raise (rb_eRuntimeError, "Cannot set value %p for key %p of record %p: %s (%d)", 
                  value, key, list, error_code_to_string (error), error);
 
    return ST_CONTINUE;
}

static VALUE
rbosa_elementrecord_new (int argc, VALUE *argv, VALUE self)
{
    OSErr           error;
    AEDescList      list;
    VALUE           hash;

    rb_scan_args (argc, argv, "01", &hash);

    if (!NIL_P (hash))
        Check_Type (hash, T_HASH);

    error = AECreateList (NULL, 0, true, &list);
    if (error != noErr) 
        rb_raise (rb_eRuntimeError, "Cannot create Apple Event descriptor list : %s (%d)", 
                  error_code_to_string (error), error);

    if (!NIL_P (hash)) 
        rb_hash_foreach (hash, __rbosa_elementrecord_set, (VALUE)&list);
    
    return rbosa_element_make (self, &list, Qnil);
}

static VALUE
rbosa_elementrecord_to_a (VALUE self)
{
    long    i, count;
    VALUE   ary;

    count = FIX2INT (rbosa_elementlist_size (self));
    ary = rb_ary_new ();
    for (i = 0; i < count; i++) {
        AEKeyword   keyword;
        char        keyStr[5];
        VALUE       val;

        val = __rbosa_elementlist_get (self, i, &keyword);
        *(AEKeyword *)keyStr = CFSwapInt32HostToBig (keyword);
        keyStr[4] = '\0';
        rb_ary_push (ary, rb_ary_new3 (2, CSTR2RVAL (keyStr), val));
    }

    return ary;
}

#define rbosa_define_param(name,default_value)                      \
    do {                                                            \
        rb_define_attr (CLASS_OF (mOSA), name, 1, 1);               \
        if (default_value == Qtrue || default_value == Qfalse)      \
            rb_define_alias (CLASS_OF (mOSA), name"?", name);       \
        rb_iv_set (mOSA, "@"name, default_value);                   \
    }                                                               \
    while (0)

void
Init_osa (void)
{
    sClasses = rb_intern ("@classes");
    sApp = rb_intern ("@app");

    mOSA = rb_define_module ("OSA");
    rb_define_module_function (mOSA, "__scripting_info__", rbosa_scripting_info, 1); 
    rb_define_module_function (mOSA, "__remote_processes__", rbosa_remote_processes, 1); 
    rb_define_module_function (mOSA, "__four_char_code__", rbosa_four_char_code, 1);

    cOSAElement = rb_define_class_under (mOSA, "Element", rb_cObject);
    rb_define_singleton_method (cOSAElement, "__new__", rbosa_element_new, 2);
    rb_define_singleton_method (cOSAElement, "__new_object_specifier__", rbosa_element_new_os, 4);
    rb_define_singleton_method (cOSAElement, "__duplicate__", rbosa_element_dup, 1);
    rb_define_method (cOSAElement, "__type__", rbosa_element_type, 0);
    rb_define_method (cOSAElement, "__data__", rbosa_element_data, -1);
    rb_define_method (cOSAElement, "before", rbosa_element_before, 0);
    rb_define_method (cOSAElement, "after", rbosa_element_after, 0);
    rb_define_method (cOSAElement, "==", rbosa_element_eql, 1);
    rb_define_method (cOSAElement, "inspect", rbosa_element_inspect, 0);

    cOSAElementList = rb_define_class_under (mOSA, "ElementList", cOSAElement);
    rb_define_singleton_method (cOSAElementList, "__new__", rbosa_elementlist_new, -1);
    rb_define_method (cOSAElementList, "[]", rbosa_elementlist_get, 1);
    rb_define_method (cOSAElementList, "size", rbosa_elementlist_size, 0);
    rb_define_alias (cOSAElementList, "length", "size");
    rb_define_method (cOSAElementList, "add", rbosa_elementlist_add, 1);

    cOSAElementRecord = rb_define_class_under (mOSA, "ElementRecord", cOSAElement);
    rb_define_singleton_method (cOSAElementRecord, "__new__", rbosa_elementrecord_new, -1);
    rb_define_method (cOSAElementRecord, "to_a", rbosa_elementrecord_to_a, 0);

    mOSAEventDispatcher = rb_define_module_under (mOSA, "EventDispatcher");
    rb_define_method (mOSAEventDispatcher, "__send_event__", rbosa_app_send_event, 4);

    rbosa_define_param ("timeout", INT2NUM (kAEDefaultTimeout));
    rbosa_define_param ("lazy_events", Qtrue);
    rbosa_define_param ("utf8_strings", Qfalse);
    rbosa_define_param ("wait_reply", Qnil);
}
