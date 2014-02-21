/* http-unitTest.p

The MIT License (MIT)

Copyright (c) 2014 James Bowen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

DEFINE VARIABLE objHttp             AS CLASS src.http         NO-UNDO.
DEFINE VARIABLE objHttpRequest      AS CLASS src.httpRequest  NO-UNDO.
DEFINE VARIABLE objHttpResponce     AS CLASS src.httpResponce NO-UNDO.


PROCEDURE HttpCallBack:
    
    DEFINE INPUT PARAMETER objHttpResponce AS CLASS src.httpResponce.
    DEFINE VARIABLE chFile AS CHARACTER   NO-UNDO.

    chFile = STRING(mtime) + '.html'.

    COPY-LOB FROM OBJECT objHttpResponce:HEADER TO FILE 'httpHeader.txt'.
    COPY-LOB FROM OBJECT objHttpResponce:BODY   TO FILE chFile.

    MESSAGE
        "FIRST LINE:" objHttpResponce:HttpResponceString 
        "Responce Code:" objHttpResponce:HttpResponceCode  
        "Responce Status:" objHttpResponce:HttpResponceStatus skip
        objHttpResponce:HEADER('Transfer-Encoding') SKIP
        objHttpResponce:HEADER('Content-Type') SKIP
        objHttpResponce:HEADER('Date')         SKIP
        VIEW-AS ALERT-BOX INFO TITLE 'Call Back Procedure'.

    RETURN.
END PROCEDURE.

objHttp        = NEW src.http().
objHttpRequest = NEW src.httpRequest().

/** Define the Call Back Procedure ...**/
objHttp:CALLBACKPROCEDURE(INPUT 'HttpCallBack',
                          INPUT THIS-PROCEDURE).

objHttp:FollowRedirect = TRUE.

objHttpRequest:HttpMethod = 'POST'.
objHttpRequest:ContenTTYPE = 'application/x-www-form-urlencoded'.
objHttpRequest:ContenTTYPE = 'multipart/form-data'.

objHttpRequest:AddParam('username','jbowen').
objHttpRequest:AddParam('password','mysuperduper password').

objHttpRequest:AddFileForUpload('fileupload','pdf-test.pdf', 'pdf-test.pdf').

objHttp:SynchronousRequest( 'http://reportingdev.cmi.co.nz/CMI/HTTPResponder.html', objHttpRequest ). 


/* objHttp:Download( 'http://mxr.mozilla.org/mozilla-central/source/security/nss/lib/ckfw/builtins/certdata.txt?raw=1', 'certdata.txt' ). */
/* objHttp:Download( 'http://www.education.gov.yk.ca/pdf/pdf-test.pdf', 'pdf-test.pdf' ). */
/* objHttp:SynchronousRequest( 'http://www.google.com' ). */
/* objHttpRequest:ADDHEADER('AUTHORIZATION', 'Basic ' + STRING(BASE64-ENCODE(mpAUTHO)) ). */

/* objHttp:SynchronousRequest( 'https://www.google.com', objHttpRequest ). */
/* objHttp:Secure = true. */                                                    


/* objHttp:Download( 'http://9to5google.files.wordpress.com/2013/12/google2.jpg', 'google2.jpg' ). */

/* objHttpRequest:ADDHEADER('Accept-Encoding', 'gzip'). */

/* objHttp:Download( 'http://www.vbaccelerator.com/home/VB/Code/vbMedia/Audio/Lossless_WAV_Compression/Sample_APE_File.zip', 'Sample_APE_File.zip' ). */
/* objHttp:Download( 'http://www.vbaccelerator.com/home/VB/Code/vbMedia/Audio/Lossless_WAV_Compression/Sample_APE_File.zip','downloads/test123.zip'). */



DELETE OBJECT objHttp.





