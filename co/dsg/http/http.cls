/* http.cls

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

USING co.dsg.http.*

CLASS src.http:

    DEFINE PRIVATE PROPERTY objURL                  AS CLASS URL                NO-UNDO GET. PRIVATE SET. 
    DEFINE PUBLIC  PROPERTY objHttpRequest          AS CLASS httpRequest        NO-UNDO GET. PRIVATE SET. 
    DEFINE PUBLIC  PROPERTY objHttpResponce         AS CLASS httpResponce       NO-UNDO GET. PRIVATE SET. 
    DEFINE PRIVATE PROPERTY objHTTPSocket           AS CLASS httpSocket         NO-UNDO GET. PRIVATE SET. 
    DEFINE PUBLIC  PROPERTY HttpHeader              AS MEMPTR                       NO-UNDO GET. PRIVATE SET. 
    DEFINE PUBLIC  PROPERTY ContentData             AS MEMPTR                       NO-UNDO GET. PRIVATE SET. 
    DEFINE PUBLIC  PROPERTY UserInfo                AS CHARACTER                    NO-UNDO GET. PRIVATE SET. 
    DEFINE PUBLIC  PROPERTY Secure                  AS LOGICAL INITIAL ?            NO-UNDO GET. SET. 
    DEFINE PUBLIC  PROPERTY FollowRedirect          AS LOGICAL INITIAL TRUE         NO-UNDO GET. SET. 
    DEFINE PRIVATE PROPERTY CallBackProcedureName   AS CHARACTER                    NO-UNDO GET. PRIVATE SET. 
    DEFINE PRIVATE PROPERTY CallBackProcedureHandle AS HANDLE                       NO-UNDO GET. PRIVATE SET.  

    CONSTRUCTOR http():
        
    END CONSTRUCTOR.

    METHOD PUBLIC CLASS src.httpResponce HttpResponce():
        RETURN THIS-OBJECT:objHttpResponce.
    END METHOD.
    
    METHOD PUBLIC VOID CALLBACKPROCEDURE
        (INPUT pchProcName   AS CHARACTER,
         INPUT phnProcHandle AS HANDLE):

        /** Is this handle Valid**/
        IF VALID-HANDLE(phnProcHandle) AND phnProcHandle:TYPE EQ 'PROCEDURE':U THEN
        DO:
            
            /** Is this procedure name valid ???**/
            IF phnProcHandle:GET-SIGNATURE(pchProcName) EQ '' THEN
                MESSAGE SUBSTITUTE('Procedure "&1" name does not exists.',
                                   pchProcName)
                    VIEW-AS ALERT-BOX WARNING.
            ELSE
                ASSIGN
                    CallBackProcedureName   = pchProcName
                    CallBackProcedureHandle = phnProcHandle.
        END.

    END METHOD.

    METHOD PRIVATE CHARACTER B64ENCODE  (INPUT pchStringToEncode AS CHARACTER):

        DEFINE VARIABLE mpAUTHO         AS MEMPTR      NO-UNDO.
        DEFINE VARIABLE chEncodedString AS CHARACTER   NO-UNDO.
        
        SET-SIZE(mpAUTHO)     = 0.
        SET-SIZE(mpAUTHO)     = LENGTH(pchStringToEncode, 'RAW') + 1.
        PUT-STRING(mpAUTHO,1) = pchStringToEncode.
            
        chEncodedString = STRING( BASE64-ENCODE(mpAUTHO) ).
        SET-SIZE(mpAUTHO)     = 0.
        
        RETURN chEncodedString.
    END METHOD.

    METHOD PUBLIC VOID BasicAuthentication (INPUT pchUserName AS CHARACTER,
                                            INPUT pchPassword AS CHARACTER):

        THIS-OBJECT:UserInfo = SUBSTITUTE('&1:&2',
                                          pchUserName,
                                          pchPassword).
    END METHOD.

    METHOD PUBLIC CLASS src.httpResponce SynchronousRequest (INPUT pchURL           AS CHARACTER,
                                                             INPUT objHttpRequest   AS CLASS src.httpRequest):

        &SCOPED-DEFINE CRLF CHR(13) + CHR(10)

        THIS-OBJECT:objURL          = NEW URL(INPUT pchURL).    /** Parse the URL for conponent parts.**/
        THIS-OBJECT:objHTTPSocket   = NEW httpSocket(). 
        THIS-OBJECT:objHttpResponce = NEW httpResponce(). 

        DEFINE VARIABLE mpHTTPDATA      AS MEMPTR      NO-UNDO.
        DEFINE VARIABLE mpHTTPContent   AS MEMPTR      NO-UNDO.
        DEFINE VARIABLE inNumParams     AS INTEGER     NO-UNDO.
        
        ASSIGN
            objHttpRequest:Path = THIS-OBJECT:objURL:Path                                WHEN ( objHttpRequest:Path EQ '/' )
            objHttpRequest:Path = (objHttpRequest:Path + '?' + THIS-OBJECT:objURL:query) WHEN ( THIS-OBJECT:objURL:query NE '').

        objHttpRequest:AddHeader('Host', THIS-OBJECT:objURL:hostname).
        objHttpRequest:AddHeader('Connection','close'). 
        /** Important to instruct the web server to close      
            the connection once the responce has been sent.**/ 
        
        /** Override the HTTP Proerties from the URL properties if they are available.**/
        ASSIGN
            THIS-OBJECT:Secure   = THIS-OBJECT:objURL:Secure   WHEN (THIS-OBJECT:objURL:Secure   NE ?) 
            THIS-OBJECT:UserInfo = THIS-OBJECT:objURL:UseRINFO WHEN (THIS-OBJECT:objURL:UserInfo NE '').

        /** BASIC Autheriation request... **/
        IF THIS-OBJECT:UserInfo NE '' THEN
            objHttpRequest:ADDHEADER('Authentication':U, 'Basic ' + B64ENCODE(THIS-OBJECT:UserInfo) ).

        /* DEBUG START...*/
        OUTPUT TO 'HttpRequest.txt' BINARY.
            PUT UNFORMATTED objHttpRequest:EntireHeader().
        OUTPUT CLOSE.
        /* DEBUG END..*/

        objHTTPSocket:Connect(THIS-OBJECT:objURL:hostname,
                              THIS-OBJECT:objURL:port,
                              THIS-OBJECT:Secure).

        IF objHTTPSocket:CONNECTED() THEN
        DO:
            /** Send the MIME HTTP Request Header **/
            DEFINE VARIABLE lgWriteScussful AS LOGICAL     NO-UNDO.

            lgWriteScussful = objHTTPSocket:WRITE( objHttpRequest:EntireHeader() ).

            /** ToDo: better error handering require..**/
            IF NOT lgWriteScussful THEN
                MESSAGE 'Did not write to socket!'
                    VIEW-AS ALERT-BOX ERROR.

            IF objHttpRequest:HttpMethod  EQ 'POST':U AND 
               objHttpRequest:ContentType EQ 'application/x-www-form-urlencoded':U THEN
            DO:
                lgWriteScussful =  objHTTPSocket:WRITE( objHttpRequest:urlEncodedParams() ).
            END.
                

            IF objHttpRequest:HttpMethod  EQ 'POST':U AND 
               objHttpRequest:ContentType EQ 'multipart/form-data':U THEN
            DO:
    
                DO inNumParams = 1 TO (objHttpRequest:NumParams):

                    DEFINE VARIABLE chParamName AS CHARACTER   NO-UNDO.
                    chParamName = objHttpRequest:getParamName(inNumParams).

                    IF chParamName NE '' THEN
                    DO:
                        objHTTPSocket:WRITE('--' + objHttpRequest:Boundary + {&CRLF}). 
                        objHTTPSocket:WRITE( SUBSTITUTE('Content-Disposition: form-data; name="&1"':U + {&CRLF}, chParamName )  ).

                        objHTTPSocket:WRITE( {&CRLF}). /** CRLF before actual value**/
                        objHTTPSocket:WRITE( objHttpRequest:getParamValue(INPUT inNumParams) + {&CRLF}).
                    END.
                END.

/*                 FOR EACH ttHttpRequestParam:                                                                                           */
/*                     objHTTPSocket:WRITE('--' + objHttpRequest:Boundary + {&CRLF}).                                                  */
/*                     objHTTPSocket:WRITE('Content-Disposition: form-data; name="&1"' + {&CRLF} ,ttHttpRequestParam.HttpParamName) ). */
/*                                                                                                                                        */
/*                     objHTTPSocket:WRITE({&CRLF}). /** CRLF before actual value**/                                                   */
/*                     objHTTPSocket:WRITE(ttHttpRequestParam.HttpParamValue).                                                            */
/*                 END.                
                                                                                                   
                                                                                                   */

                DEFINE VARIABLE hnFormDataBuffer AS HANDLE      NO-UNDO.
                DEFINE VARIABLE hnQuery          AS HANDLE      NO-UNDO.

                /** Temp-Table handle**/
                hnFormDataBuffer = objHttpRequest:FormData:DEFAULT-BUFFER-HANDLE.
                
                CREATE QUERY hnQuery.

                hnQuery:SET-BUFFERS(hnFormDataBuffer).
                hnQuery:QUERY-PREPARE("FOR EACH ttFormData").
                
                IF hnQuery:QUERY-OPEN() THEN
                DO:
                    hnQuery:GET-FIRST().
    
                    DO WHILE NOT hnQuery:QUERY-OFF-END.
    
                        IF hnFormDataBuffer:AVAILABLE THEN
                        DO:
    
                            objHTTPSocket:WRITE('--' + objHttpRequest:Boundary + {&CRLF}). 
                            objHTTPSocket:WRITE(SUBSTITUTE('Content-Disposition: form-data; name="&1"; filename="&2"':U + {&CRLF}, 
                                                           hnFormDataBuffer::FormName,
                                                           hnFormDataBuffer::RemoteFilename)
                                                 ).
        
                            objHTTPSocket:WRITE(SUBSTITUTE('Content-Type: &1':U + {&CRLF}, hnFormDataBuffer::ContentType)   ). 
            
                            IF hnFormDataBuffer::ContentType NE 'text/plain':U THEN
                                objHTTPSocket:WRITE('Content-Transfer-Encoding: binary' + {&CRLF}).
            
                            objHTTPSocket:WRITE({&CRLF}). /** CRLF before actual value**/

                            DEFINE VARIABLE mpTempBlobData AS MEMPTR      NO-UNDO.

                            SET-SIZE(mpTempBlobData) = 0.
                            COPY-LOB FROM OBJECT hnFormDataBuffer::BlobData TO mpTempBlobData.
                            objHTTPSocket:WRITE( mpTempBlobData ).
                            SET-SIZE(mpTempBlobData) = 0.

                            objHTTPSocket:WRITE( {&CRLF} ).
                        END.
    
                        hnQuery:GET-NEXT().
                    END.
                    hnQuery:QUERY-CLOSE().

                END.
                
                DELETE OBJECT hnQuery.

                objHTTPSocket:WRITE('--' + objHttpRequest:Boundary + '--'). /** END OF POST...**/
    
            END.

            mpHTTPDATA = objHTTPSocket:READ().

            /** Effectivly split the header and body into two parts. 
                This method also handles the chunked encoded body. **/

            objHttpResponce:ParseHTTPResponce(mpHTTPDATA).
            
/*             MESSAGE objHttpResponce:HttpResponceString SKIP */
/*                     objHttpResponce:header('Location') SKIP */
/*                     objHttpResponce:header('Date') SKIP(1)  */
/*                     objHttpResponce:header()                */
/*                 VIEW-AS ALERT-BOX INFO.                     */

/*             COPY-LOB FROM OBJECT objHttpResponce:HEADER TO FILE 'HTTPHeaderDebug.txt'. */

            SET-SIZE(mpHTTPDATA) = 0 .
            
/*             COPY-LOB FROM OBJECT mpHTTPDATA    STARTING AT HttpHeader:STARTINGCONTENTAT TO THIS-OBJECT:ContentData. */
/*             COPY-LOB FROM OBJECT mpHTTPContent                                          TO FILE './HttpResponceData.txt'. */
        
        END.
        
        /** Delete the Class object...**/
        DELETE OBJECT THIS-OBJECT:objHTTPSocket.
        DELETE OBJECT THIS-OBJECT:objURL. 

        /** Logic to Follow Http 302 URL rediects**/
        IF objHttpResponce:HttpResponceCode EQ 302 AND THIS-OBJECT:FollowRedirect THEN
        DO:

            /***
               Need a loop counter to stop continues redirects 
               which could follow into a never ending loop.
             ***/
            objHttpResponce = THIS-OBJECT:SynchronousRequest(INPUT objHttpResponce:header('Location'), /** The new location **/
                                                             INPUT THIS-OBJECT:objHttpRequest).        /** Continue passsing the orignal HTTP Request.**/
        END.
        ELSE
        DO:

            IF VALID-HANDLE(THIS-OBJECT:CallBackProcedureHandle) THEN
                RUN VALUE(THIS-OBJECT:CallBackProcedureName) IN THIS-OBJECT:CallBackProcedureHandle (INPUT objHttpResponce).

        END.

        IF VALID-OBJECT(THIS-OBJECT:objHttpRequest) THEN
            DELETE OBJECT THIS-OBJECT:objHttpRequest.

        RETURN THIS-OBJECT:objHttpResponce.
    END METHOD.

    METHOD PUBLIC CLASS src.httpResponce SynchronousRequest (INPUT pchURL AS CHARACTER):
        
        /** Request method defaults to 'GET' **/
        THIS-OBJECT:objHttpRequest = NEW HttpRequest().

        RETURN SynchronousRequest(INPUT pchURL, 
                                  INPUT THIS-OBJECT:objHttpRequest).

    END METHOD.

    METHOD PUBLIC LOGICAL Download (INPUT pchURL     AS CHARACTER):
        
        /** Request method defaults to 'GET' **/
        THIS-OBJECT:objHttpRequest = NEW HttpRequest().

        RETURN THIS-OBJECT:Download(INPUT pchURL,
                                    INPUT THIS-OBJECT:objHttpRequest,
                                    INPUT '').

    END METHOD.

    METHOD PUBLIC LOGICAL Download  (INPUT pchURL     AS CHARACTER,
                                     INPUT pcFileName AS CHARACTER):
        
        /** Request method defaults to 'GET' **/
        THIS-OBJECT:objHttpRequest = NEW HttpRequest().

        RETURN THIS-OBJECT:Download(INPUT pchURL,
                                    INPUT THIS-OBJECT:objHttpRequest,
                                    INPUT pcFileName).

    END METHOD.

    METHOD PUBLIC LOGICAL Download (INPUT pchURL           AS CHARACTER,
                                    INPUT objHttpRequest   AS CLASS src.HttpRequest,
                                    INPUT pcFileName       AS CHARACTER):

        DEFINE VARIABLE objDownloadResponce AS CLASS src.HttpResponce NO-UNDO.
        DEFINE VARIABLE objDownloadURL      AS CLASS src.URL NO-UNDO.
        DEFINE VARIABLE chDirectory         AS CHARACTER   NO-UNDO.

        FILE-INFO:FILE-NAME = '.'.
        chDirectory = FILE-INFO:FULL-PATHNAME.

        objDownloadResponce = THIS-OBJECT:SynchronousRequest(INPUT pchURL, 
                                                             INPUT objHttpRequest).
        
        objDownloadURL = NEW URL(INPUT pchURL).

        IF pcFileName NE '' THEN
        DO:

            FILE-INFO:FILE-NAME = pcFileName.

            /*** Is it a directory? ***/
            IF FILE-INFO:FILE-TYPE MATCHES '*D*' THEN
            DO:
                ASSIGN 
                    chDirectory = FILE-INFO:FULL-PATHNAME
                    chDirectory = RIGHT-TRIM(chDirectory,'/').
                    pcFileName  = ''.

                /** Assign a random file name if it's not available from file..**/
                IF objDownloadURL:filename EQ '' THEN
                    pcFileName =  chDirectory + '/' + STRING(HEX-ENCODE(GENERATE-UUID)) + '.tmp'.
                ELSE
                    pcFileName =  chDirectory + '/' + objDownloadURL:filename.
            END.
        END.
        ELSE
        DO:
            /** Assign a RANDOM FILEname.**/
            pcFileName =  chDirectory + '/' + STRING(HEX-ENCODE(GENERATE-UUID)) + '.tmp'. 
        END.

        DELETE OBJECT objDownloadURL.

        COPY-LOB FROM OBJECT objDownloadResponce:Body TO FILE pcFileName NO-ERROR.

        SET-SIZE(objDownloadResponce:HEADER) = 0.
        SET-SIZE(objDownloadResponce:Body)   = 0.

        RETURN (IF ERROR-STATUS:ERROR THEN FALSE ELSE TRUE).    

    END METHOD.



END CLASS.


