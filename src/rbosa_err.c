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

#include <CoreServices/CoreServices.h>

const char *
error_code_to_string (const int code)
{
  switch (code) {
    case noPortErr: return "Client hasn't set 'SIZE' resource to indicate awareness of high-level events";
    case destPortErr: return "Server hasn't set 'SIZE' resource to indicate awareness of high-level events, or else is not present";
    case sessClosedErr: return "The kAEDontReconnect flag in the sendMode parameter was set and the server quit, then restarted";
    case errAECoercionFail: return "Data could not be coerced to the requested descriptor type";
    case errAEDescNotFound: return "Descriptor was not found";
    case errAECorruptData: return "Data in an Apple event could not be read";
    case errAEWrongDataType: return "Wrong descriptor type";
    case errAENotAEDesc: return "Not a valid descriptor";
    case errAEBadListItem: return "Operation involving a list item failed";
    case errAENewerVersion: return "Need a newer version of the Apple Event Manager";
    case errAENotAppleEvent: return "The event is not in AppleEvent format.";
    case errAEEventNotHandled: return "Event wasn't handled by an Apple event handler";
    case errAEReplyNotValid: return "AEResetTimer was passed an invalid repl";
    case errAEUnknownSendMode: return "Invalid sending mode was passed";
    case errAEWaitCanceled: return "User canceled out of wait loop for reply or receipt";
    case errAETimeout: return "Apple event timed out";
    case errAENoUserInteraction: return "No user interaction allowed";
    case errAENotASpecialFunction: return "Wrong keyword for a special function";
    case errAEParamMissed: return "A required parameter was not accessed.";
    case errAEUnknownAddressType: return "Unknown Apple event address type";
    case errAEHandlerNotFound: return "No handler found for an Apple event";
    case errAEReplyNotArrived: return "Reply has not yet arrived";
    case errAEIllegalIndex: return "Not a valid list index";
    case errAEImpossibleRange: return "The range is not valid because it is impossible for a range to include the first and last objects that were specified; an example is a range in which the offset of the first object is greater than the offset of the last object";
    case errAEWrongNumberArgs: return "The number of operands provided for the kAENOT logical operator is not 1";
    case errAEAccessorNotFound: return "There is no object accessor function for the specified object class and container type";
    case errAENoSuchLogical: return "The logical operator in a logical descriptor is not kAEAND, kAEOR, or kAENOT";
    case errAEBadTestKey: return "The descriptor in a test key is neither a comparison descriptor nor a logical descriptor";
    case errAENotAnObjSpec: return "The objSpecifier parameter of AEResolve is not an object specifier";
    case errAENoSuchObject: return "Runtime resolution of an object failed.";
    case errAENegativeCount: return "An object-counting function returned a negative result";
    case errAEEmptyListContainer: return "The container for an Apple event object is specified by an empty list";
    case errAEUnknownObjectType: return "The object type isn't recognized";
    case errAERecordingIsAlreadyOn: return "Recording is already on";
    case errAEReceiveTerminate: return "Break out of all levels of AEReceive to the topmost (1.1 or greater)";
    case errAEReceiveEscapeCurrent: return "Break out of lowest level only of AEReceive (1.1 or greater)";
    case errAEEventFiltered: return "Event has been filtered and should not be propagated (1.1 or greater)";
    case errAEDuplicateHandler: return "Attempt to install handler in table for identical class and ID (1.1 or greater)";
    case errAEStreamBadNesting: return "Nesting violation while streaming";
    case errAEStreamAlreadyConverted: return "Attempt to convert a stream that has already been converted";
    case errAEDescIsNull: return "Attempt to perform an invalid operation on a null descriptor";
    case errAEBuildSyntaxError: return "AEBuildDesc and related functions detected a syntax error";
    case errAEBufferTooSmall: return "Buffer for AEFlattenDesc too small";
    case errASCantConsiderAndIgnore: return "Can't both consider and ignore <attribute>.";
    case errASCantCompareMoreThan32k: return "Can't perform operation on text longer than 32K bytes.";
    case errASTerminologyNestingTooDeep: return "Tell statements are nested too deeply.";
    case errASIllegalFormalParameter: return "<name> is illegal as a formal parameter.";
    case errASParameterNotForEvent: return "<name> is not a parameter name for the event <event>.";
    case errASNoResultReturned: return "No result was returned for some argument of this expression.";
    case errAEEventFailed: return "Apple event handler failed.";
    case errAETypeError: return "A descriptor type mismatch occurred.";
    case errAEBadKeyForm: return "Invalid key form.";
    case errAENotModifiable: return "Can't set <object or data> to <object or data>. Access not allowed.";
    case errAEPrivilegeError: return "A privilege violation occurred.";
    case errAEReadDenied: return "The read operation was not allowed.";
    case errAEWriteDenied: return "Can't set <object or data> to <object or data>.";
    case errAEIndexTooLarge: return "The index of the event is too large to be valid.";
    case errAENotAnElement: return "The specified object is a property, not an element.";
    case errAECantSupplyType: return "Can't supply the requested descriptor type for the data.";
    case errAECantHandleClass: return "The Apple event handler can't handle objects of this class.";
    case errAEInTransaction: return "Couldn't handle this command because it wasn't part of the current transaction.";
    case errAENoSuchTransaction: return "The transaction to which this command belonged isn't a valid transaction.";
    case errAENoUserSelection: return "There is no user selection.";
    case errAENotASingleObject: return "Handler only handles single objects.";
    case errAECantUndo: return "Can't undo the previous Apple event or user action.";
    case errAENotAnEnumMember: return "Enumerated value in SetData is not allowed for this property";
    case errAECantPutThatThere: return "In make new, duplicate, etc. class can't be an element of container";
    case errAEPropertiesClash: return "Illegal combination of properties settings for SetData, make new, or duplicate";
  }
  return GetMacOSStatusErrorString (code);
}
