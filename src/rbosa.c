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

#include "rbosa.h"

static VALUE mOSA;
static VALUE cOSAElement;
static VALUE cOSAElementList;
static VALUE cOSAApplication;

static ID sClasses;
static ID sApp;

static void
rbosa_element_free (void *ptr)
{
    AEDisposeDesc (ptr);
    free (ptr);
}

static VALUE
rbosa_element_make (VALUE klass, AEDesc *desc, VALUE app)
{
    AEDesc *    newDesc;
    VALUE       obj;

    newDesc = (AEDesc *)malloc (sizeof (AEDesc));
    memcpy (newDesc, desc, sizeof (AEDesc));

    /* Let's replace the klass here according to the type of the descriptor,
     * if the basic class OSA::Element was given.
     */
    if (klass == cOSAElement) {
        char    dtStr[5];
    
        *(DescType*)dtStr = CFSwapInt32HostToBig (newDesc->descriptorType);
        dtStr[4] = '\0';

        if (strcmp (dtStr, "list") == 0) {
            klass = cOSAElementList;
        }
        else if (strcmp (dtStr, "obj ") == 0 && !NIL_P (app)) {
            VALUE   classes;
            VALUE   new_klass;        

            classes = rb_ivar_get (app, sClasses);
            new_klass = rb_hash_aref (classes, CSTR2RVAL (dtStr));
            if (NIL_P (new_klass)) {
                AEDesc  res;
                OSErr   err;

                if ((err = AEGetParamDesc ((AppleEvent *)newDesc, 'want', '****', &res)) == noErr) {
                    char *data;
                    Size datasize;
                    
                    datasize = AEGetDescDataSize (&res);
                    data = (void *)malloc (datasize);
                  
                    if (AEGetDescData (&res, data, datasize) == noErr) {
                        char *p;
#if defined(__LITTLE_ENDIAN__)
                        char b[5];
                        b[0] = data[3];
                        b[1] = data[2];
                        b[2] = data[1];
                        b[3] = data[0];
                        p = b;
#else
                        p = data;
#endif
                        if (datasize > 3)
                            p[4] = '\0';
                        new_klass = rb_hash_aref (classes, CSTR2RVAL (p));
                    }

                    free (data);
                }
            }

            if (!NIL_P (new_klass))
                klass = new_klass; 
        }
    }

    obj = Data_Wrap_Struct (klass, NULL, rbosa_element_free, newDesc);

    if (!NIL_P (app))
        rb_ivar_set (obj, sApp, app);

    return obj;
}

static AEDesc *
rbosa_element_aedesc (VALUE element)
{
    AEDesc *    desc;

    if (!rb_obj_is_kind_of (element, cOSAElement))
        rb_raise (rb_eArgError, "Invalid argument of type '%s' (required: OSA::Element)", rb_class2name (element));

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
        c_value = RVAL2CSTR (value);
        c_value_size = strlen (c_value);
    }

    error = AECreateDesc (ffc_type, c_value, c_value_size, &desc);
    if (error != noErr)     
        rb_raise (rb_eArgError, "Cannot create Apple Event descriptor from type '%s' value '%s' : %s (%d)", 
                  RVAL2CSTR (type), c_value, GetMacOSStatusErrorString (error), error);

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
                  RVAL2CSTR (desired_class), GetMacOSStatusErrorString (error), error);

    return rbosa_element_make (self, &obj_specifier, Qnil);
}

static VALUE
rbosa_app_send_event (VALUE self, VALUE event_class, VALUE event_id, VALUE params, VALUE need_retval)
{
    OSErr       error;
    AppleEvent  ae;
    AppleEvent  reply;

    error = AECreateAppleEvent (RVAL2FOURCHAR (event_class),
                                RVAL2FOURCHAR (event_id),
                                rbosa_element_aedesc (self),
                                kAutoGenerateReturnID,
                                kAnyTransactionID,
                                &ae);
    if (error != noErr)
        rb_raise (rb_eArgError, "Cannot create Apple Event '%s%s' : %s (%d)", 
                  RVAL2CSTR (event_class), RVAL2CSTR (event_id), GetMacOSStatusErrorString (error), error);

    if (!NIL_P (params)) {
        unsigned    i;

        for (i = 0; i < RARRAY (params)->len; i++) {
            VALUE   ary;
            VALUE   type;
            VALUE   element;

            ary = RARRAY (params)->ptr[i];
            if (NIL_P (ary) || RARRAY (ary)->len != 2)
                continue;

            type = RARRAY (ary)->ptr[0];
            element = RARRAY (ary)->ptr[1];

            error = AEPutParamDesc (&ae, RVAL2FOURCHAR (type), rbosa_element_aedesc (element));
            if (error != noErr) { 
                AEDisposeDesc (&ae); 
                rb_raise (rb_eArgError, "Cannot add Apple Event parameter '%s' : %s (%d)", 
                          RVAL2CSTR (type), GetMacOSStatusErrorString (error), error);
            }
        } 
    }

    error = AESend (&ae, &reply, (RVAL2CBOOL(need_retval) ? kAEWaitReply : kAENoReply) | kAENeverInteract | kAECanSwitchLayer,
                    kAENormalPriority, kAEDefaultTimeout, NULL, NULL);

    AEDisposeDesc (&ae); 

    if (error != noErr)
        rb_raise (rb_eRuntimeError, "Cannot send Apple Event '%s%s' : %s (%d)", 
                  RVAL2CSTR (event_class), RVAL2CSTR (event_id), GetMacOSStatusErrorString (error), error);

    if (RTEST (need_retval)) {
        VALUE   rb_reply;
        AEDesc  replyObject;

        AEGetParamDesc (&reply, keyDirectObject, typeWildCard, &replyObject);

        rb_reply = rbosa_element_make (cOSAElement, &replyObject, self);
        
        return rb_reply; 
    }
    return Qnil;
}

static VALUE
rbosa_element_type (VALUE self)
{
    AEDesc  *desc;
    char    dtStr[5];

    desc = rbosa_element_aedesc (self);
    *(DescType*)dtStr = CFSwapInt32HostToBig (desc->descriptorType);
    dtStr[4] = '\0';

    return CSTR2RVAL (dtStr);
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

    rb_scan_args (argc, argv, "01", &coerce_type);

    desc  = rbosa_element_aedesc (self);
    
    if (!NIL_P (coerce_type)) {
        error = AECoerceDesc (desc, RVAL2FOURCHAR (coerce_type), &coerced_desc);
        if (error != noErr)
            rb_raise (rb_eRuntimeError, "Cannot coerce desc to type %s : %s (%d)", 
                      RVAL2CSTR (coerce_type), GetMacOSStatusErrorString (error), error);
        
        desc = &coerced_desc;
    }

    datasize = AEGetDescDataSize (desc);
    data = (void *)malloc (datasize);
  
    error = AEGetDescData (desc, data, datasize);
    retval = error == noErr ? rb_str_new (data, datasize) : Qnil;

    if (!NIL_P (coerce_type))
        AEDisposeDesc (&coerced_desc); 
    free (data);

    if (error != noErr)
        rb_raise (rb_eRuntimeError, "Cannot get desc data : %s (%d)", 
                  GetMacOSStatusErrorString (error), error);
    
    return retval; 
}

static VALUE
rbosa_elementlist_get (VALUE self, VALUE index)
{
    OSErr       error;
    AEDesc      desc;
    AEKeyword   keyword;

    error = AEGetNthDesc ((AEDescList *)rbosa_element_aedesc (self),
                          FIX2INT (index) + 1,
                          typeWildCard,
                          &keyword,
                          &desc);
    
    if (error != noErr)
        rb_raise (rb_eRuntimeError, "Cannot get desc at index %d : %s (%d)", 
                  FIX2INT (index), GetMacOSStatusErrorString (error), error);

    return rbosa_element_make (cOSAElement, &desc, rb_ivar_get (self, sApp));
}

static VALUE
rbosa_elementlist_size (VALUE self)
{
    OSErr   error;
    long    count;
    
    count = 0;
    error = AECountItems ((AEDescList *)rbosa_element_aedesc (self), &count);
    if (error != noErr)
        rb_raise (rb_eRuntimeError, "Cannot count items : %s (%d)", 
                  GetMacOSStatusErrorString (error), error);

    return INT2FIX (count);
}

void
Init_osa (void)
{
    sClasses = rb_intern ("@classes");
    sApp = rb_intern ("@app");

    mOSA = rb_define_module ("OSA");
    rb_define_module_function (mOSA, "__scripting_info__", rbosa_scripting_info, 2); 
    rb_define_module_function (mOSA, "__four_char_code__", rbosa_four_char_code, 1);

    cOSAElement = rb_define_class_under (mOSA, "Element", rb_cObject);
    rb_define_singleton_method (cOSAElement, "__new__", rbosa_element_new, 2);
    rb_define_singleton_method (cOSAElement, "__new_object_specifier__", rbosa_element_new_os, 4);
    rb_define_method (cOSAElement, "__type__", rbosa_element_type, 0);
    rb_define_method (cOSAElement, "__data__", rbosa_element_data, -1);

    cOSAElementList = rb_define_class_under (mOSA, "ElementList", cOSAElement);
    rb_define_method (cOSAElementList, "[]", rbosa_elementlist_get, 1);
    rb_define_method (cOSAElementList, "size", rbosa_elementlist_size, 0);
    rb_define_alias (cOSAElementList, "length", "size");

    cOSAApplication = rb_define_class_under (mOSA, "Application", cOSAElement);
    rb_define_method (cOSAApplication, "__send_event__", rbosa_app_send_event, 4);
}
