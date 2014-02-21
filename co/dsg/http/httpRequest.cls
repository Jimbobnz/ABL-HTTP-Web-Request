CLASS src.httpRequest:

    DEFINE PUBLIC PROPERTY CHARSET          AS CHARACTER NO-UNDO GET. SET.
    DEFINE PUBLIC PROPERTY ContentType      AS CHARACTER NO-UNDO GET. SET.
    DEFINE PUBLIC PROPERTY HttpMethod       AS CHARACTER NO-UNDO GET. SET.
    DEFINE PUBLIC PROPERTY HttpVersion      AS CHARACTER NO-UNDO GET. SET.
    DEFINE PUBLIC PROPERTY Path             AS CHARACTER NO-UNDO GET. SET.
    DEFINE PUBLIC PROPERTY Boundary         AS CHARACTER NO-UNDO GET. PRIVATE SET.
    DEFINE PUBLIC PROPERTY NumHeaderFields  AS INTEGER   NO-UNDO GET. PRIVATE SET. 
    DEFINE PUBLIC PROPERTY NumParams        AS INTEGER   NO-UNDO GET. PRIVATE SET. 
    DEFINE PUBLIC PROPERTY ContentLength    AS INTEGER   NO-UNDO GET. PRIVATE SET. 
    DEFINE PUBLIC PROPERTY FormData         AS HANDLE    NO-UNDO GET. PRIVATE SET. 
    
    DEFINE PRIVATE TEMP-TABLE ttHttpRequestHeader NO-UNDO
        FIELD HttpHeaderName   AS CHARACTER 
        FIELD HttpHeaderValue  AS CHARACTER
        FIELD HttpHeaderIndex  AS INTEGER
        INDEX idxHeaderName IS UNIQUE PRIMARY
            HttpHeaderName
        INDEX idxHeaderIndex 
            HttpHeaderIndex.

    DEFINE PRIVATE TEMP-TABLE ttHttpRequestParam NO-UNDO
        FIELD HttpParamName    AS CHARACTER 
        FIELD HttpParamValue   AS CHARACTER
        FIELD HttpParamIndex   AS INTEGER
        FIELD HttpParamEncoded AS CHARACTER
        FIELD HttpParamSize    AS INTEGER
        INDEX idxParamName IS UNIQUE PRIMARY
            HttpParamName
        INDEX idxParamIndex 
            HttpParamIndex.

    DEFINE TEMP-TABLE ttFormData NO-UNDO
        FIELD FormName       AS CHARACTER
        FIELD RemoteFilename AS CHARACTER
        FIELD BlobData       AS BLOB
        FIELD BLOBSIZE       AS INTEGER
        FIELD ContentType    AS CHARACTER
        INDEX idxFormName  IS PRIMARY
            FormName.


    CONSTRUCTOR httpRequest():

        THIS-OBJECT:CHARSET         = SESSION:CPINTERNAL.
        THIS-OBJECT:ContentType     = 'text/html'.
        THIS-OBJECT:HttpMethod      = 'GET'.
        THIS-OBJECT:HttpVersion     = '1.1'.
        THIS-OBJECT:Path            = '/'.
        THIS-OBJECT:NumHeaderFields = 0. 
        THIS-OBJECT:NumParams       = 0.
        THIS-OBJECT:Boundary        = HEX-ENCODE(GENERATE-UUID).   /** Used for multi-part posts**/ 

        THIS-OBJECT:FormData = TEMP-TABLE ttFormData:HANDLE.

    END CONSTRUCTOR.


    METHOD VOID AddHeader(INPUT pchHeader   AS CHARACTER,
                          INPUT pchValue    AS CHARACTER):
        /** 
            Adds a request header to the HTTP request. If a header having the 
            same field name is already present, this method replaces it.
        **/       

        FIND ttHttpRequestHeader
            WHERE ttHttpRequestHeader.HttpHeaderName EQ pchHeader
            NO-ERROR.

        IF NOT AVAILABLE ttHttpRequestHeader THEN
        DO:

            THIS-OBJECT:NumHeaderFields = THIS-OBJECT:NumHeaderFields + 1.

            CREATE ttHttpRequestHeader.
            ASSIGN
                ttHttpRequestHeader.HttpHeaderName  = pchHeader
                ttHttpRequestHeader.HttpHeaderIndex = THIS-OBJECT:NumHeaderFields.
        END.
            
        ASSIGN
            ttHttpRequestHeader.HttpHeaderValue  = TRIM(pchValue).

        IF TRIM(pchValue) EQ '' THEN
            DELETE ttHttpRequestHeader.
    END METHOD.

    METHOD PUBLIC VOID AddStringForUpload(INPUT pchFormName       AS CHARACTER,
                                          INPUT pchFilenameTarget AS CHARACTER,
                                          INPUT pchString         AS LONGCHAR):

        THIS-OBJECT:AddStringForUpload(INPUT pchFormName,
                                       INPUT pchFilenameTarget,
                                       INPUT pchString,
                                       INPUT 'plain/text':U). /** Default the content type to plain/text **/
    END METHOD.

    METHOD PUBLIC VOID AddStringForUpload(INPUT pchFormName       AS CHARACTER,
                                          INPUT pchFilenameTarget AS CHARACTER,
                                          INPUT pchString         AS LONGCHAR,
                                          INPUT pchContentType    AS CHARACTER):

        DEFINE VARIABLE mpData AS MEMPTR      NO-UNDO.
            
        SET-SIZE(mpData) = 0.

        COPY-LOB FROM OBJECT pchString to OBJECT mpData.       
            
        THIS-OBJECT:AddBinaryForUpload(INPUT pchFormName, 
                                       INPUT pchFilenameTarget, 
                                       INPUT mpData,    
                                       INPUT pchContentType).

        SET-SIZE(mpData) = 0.

    END METHOD.

    METHOD PUBLIC VOID AddFileForUpload(INPUT pchFormName       AS CHARACTER,
                                        INPUT pchFilenameTarget AS CHARACTER,
                                        INPUT pchFilenameSource AS CHARACTER):

        /** ToDo: Guess the content mime/type depending on the file extention.**/

        /** Sanitise the filename of the target**/
        ASSIGN
            pchFilenameSource   = REPLACE(pchFilenameSource,'~\','/')
            pchFilenameTarget   = REPLACE(pchFilenameTarget,'~\','/').

        DEFINE VARIABLE chExtention   AS CHARACTER   NO-UNDO.
        DEFINE VARIABLE chContentType AS CHARACTER   NO-UNDO.

        chExtention = SUBSTRING(pchFilenameTarget,R-INDEX(pchFilenameTarget,'.') + 1).

        /** Auto detechtion of content type based on file extention...**/
        /** TODO: Convert into a Class Object...*/

        CASE chExtention:
            WHEN 'jpg'  THEN
                chContentType = 'images/jpeg'.
            WHEN 'gif'  THEN
                chContentType = 'images/gif'.
            WHEN 'png'  THEN
                chContentType = 'images/png'.
            WHEN 'svg'  THEN
                chContentType = 'images/svg+xml'.
            WHEN 'css' THEN
                chContentType = 'text/css'.
            WHEN 'csv' THEN
                chContentType = 'text/csv'.
            WHEN 'html' OR WHEN 'html' THEN
                chContentType = 'text/html'.
            WHEN 'js' THEN
                chContentType = 'text/javascript'.
            WHEN 'txt' THEN
                chContentType = 'text/plain'.
            WHEN 'xml' THEN
                chContentType = 'application/xml'.
            WHEN 'pdf' THEN
                chContentType = 'application/pdf'.
            WHEN 'zip' THEN
                chContentType = 'application/zip'.
            WHEN 'zg' THEN
                chContentType = 'application/gzip'.
            WHEN 'ps' THEN
                chContentType = 'application/postscript'.
            WHEN 'json' THEN
                chContentType = 'application/json'.
            WHEN 'atom' THEN
                chContentType = 'application/atom+xml'.
            WHEN 'rss' THEN
                chContentType = 'application/rss+xml'.
            WHEN 'soap' THEN
                chContentType = 'application/soap+xml'.
            WHEN 'xls' THEN
                chContentType = 'application/vnd.ms-excel'.
            WHEN 'xlsx' THEN
                chContentType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.
            WHEN 'doc' THEN
                chContentType = 'application/vnd.ms-word'.
            WHEN 'docx' THEN
                chContentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'.

            OTHERWISE
                chContentType = 'application/octet-stream':U. /**  Arbitrary binary data**/

        END CASE.
        
        THIS-OBJECT:AddFileForUpload(INPUT pchFormName,       
                                     INPUT pchFilenameTarget,       
                                     INPUT pchFilenameSource,             
                                     INPUT chContentType). /** Default the content type to application/octet-stream **/  


            
    END METHOD.        

    METHOD PUBLIC VOID AddFileForUpload(INPUT pchFormName       AS CHARACTER,
                                        INPUT pchFilenameTarget AS CHARACTER,
                                        INPUT pchFilenameSource AS CHARACTER,
                                        INPUT pchContentType    AS CHARACTER):

        DEFINE VARIABLE mpData AS MEMPTR  NO-UNDO.
        SET-SIZE(mpData) = 0.

        /** Sanitise the directory paths to a *nix syntax... **/
        pchFilenameSource = REPLACE(pchFilenameSource ,'~\','/').
        pchFilenameTarget = SUBSTRING(pchFilenameTarget,R-INDEX(pchFilenameTarget,'/') + 1). /** Make sure that **/

        IF SEARCH(pchFilenameSource) NE ? THEN
        DO:
            
            COPY-LOB FROM FILE pchFilenameSource TO OBJECT mpData.       
    
            THIS-OBJECT:AddBinaryForUpload(INPUT pchFormName,       
                                           INPUT pchFilenameTarget,       
                                           INPUT mpData,             
                                           INPUT pchContentType).   
        END.

        SET-SIZE(mpData) = 0.

    END METHOD.        

    METHOD PUBLIC VOID AddBinaryForUpload(INPUT pchFormName         AS CHARACTER,
                                          INPUT pchFilenameTarget   AS CHARACTER,
                                          INPUT pmpBlobData         AS MEMPTR):

        THIS-OBJECT:AddBinaryForUpload(INPUT pchFormName,
                                       INPUT pchFilenameTarget,
                                       INPUT pmpBlobData,
                                       INPUT 'application/octet-stream').

        SET-SIZE(pmpBlobData) = 0.
    END METHOD.

    METHOD PUBLIC VOID AddBinaryForUpload(INPUT pchFormName         AS CHARACTER,
                                          INPUT pchFilenameTarget   AS CHARACTER,
                                          INPUT pmpBlobData         AS MEMPTR,
                                          INPUT pchContentType      AS CHARACTER):

        CREATE ttFormData.

        ASSIGN 
            ttFormData.FormName         = pchFormName 
            ttFormData.RemoteFilename   = pchFilenameTarget
            ttFormData.BLOBSIZE         = GET-SIZE(pmpBlobData)  
            ttFormData.ContentType      = pchContentType.

        COPY-LOB FROM OBJECT pmpBlobData TO OBJECT ttFormData.BlobData.

        SET-SIZE(pmpBlobData) = 0.
    END METHOD.

    METHOD CHARACTER HeaderField (INPUT pchHeader AS CHARACTER):
        /**
            Returns the value of a request header field.   
         **/
        FIND ttHttpRequestHeader
            WHERE ttHttpRequestHeader.HttpHeaderName EQ pchHeader
            NO-ERROR.
                                                                                           
        RETURN (IF AVAILABLE ttHttpRequestHeader THEN ttHttpRequestHeader.HttpHeaderValue ELSE '').

    END METHOD.

    METHOD CHARACTER HeaderName (INPUT pinIndex AS INTEGER ):
        /**
            Returns the Nth request header field name. Indexing begins at 1, and the 
            number of request header fields is specified by the NumHeaderFields property.
        **/            
        FIND ttHttpRequestHeader
            WHERE ttHttpRequestHeader.HttpHeaderIndex EQ pinIndex
            NO-ERROR.

        RETURN (IF AVAILABLE ttHttpRequestHeader THEN ttHttpRequestHeader.HttpHeaderName ELSE '').

    END METHOD.

    METHOD VOID RemoveHeader(INPUT pchHeader AS CHARACTER):
        
          /** 
             Removes a single HTTP header field parameter by name. 
          **/

          FIND ttHttpRequestHeader
            WHERE ttHttpRequestHeader.HttpHeaderName EQ pchHeader
            NO-ERROR.

          IF AVAILABLE ttHttpRequestHeader THEN
          DO:
              DELETE ttHttpRequestHeader.
              THIS-OBJECT:NumHeaderFields = THIS-OBJECT:NumHeaderFields - 1.

              /** Internal House keeping to maintaing header field indexing. **/
              DEFINE VARIABLE inNewIndex AS INTEGER     NO-UNDO.

              FOR EACH ttHttpRequestHeader
                  BY ttHttpRequestHeader.HttpHeaderIndex:

                  ASSIGN
                      inNewIndex                      = inNewIndex + 1
                      ttHttpRequestHeader.HttpHeaderIndex = inNewIndex.
              END.
                
              /** Re-assign the NumHeaderFields property to the last know index. **/
              THIS-OBJECT:NumHeaderFields = inNewIndex.

          END.
    END METHOD.

    METHOD PUBLIC CHARACTER EntireHeader():
        
        &SCOPED-DEFINE CRLF chr(13) + chr(10)
        
        DEFINE VARIABLE chHTTPRequestHeader AS CHARACTER   NO-UNDO.
        DEFINE VARIABLE chPath              AS CHARACTER   NO-UNDO.

        chHTTPRequestHeader = ''.

        /** Automatically add the 'Accept' Header if not supplied..**/
        IF THIS-OBJECT:HeaderField('Accept') EQ '' THEN
            THIS-OBJECT:AddHeader('Accept', '*/*' ).

        /** Automatically add the 'User-Agent' if it has not already been specified..**/
        IF THIS-OBJECT:HeaderField('User-Agent') EQ '' THEN
            THIS-OBJECT:AddHeader('User-Agent', 'OpenEdge ' + PROVERSION(1) + ' ({&OPSYS}; {&WINDOW-SYSTEM}{&PROCESS-ARCHITECTURE})'  ).

        

        chPath = TRIM(THIS-OBJECT:path).

        IF THIS-OBJECT:HttpMethod EQ 'GET':U AND NumParams GT 0 THEN
        DO:
            IF INDEX(path,'?') GT 0 THEN
                chPath = chPath + '&' + THIS-OBJECT:urlEncodedParams(). /** Append to query string..**/
            ELSE
                chPath = chPath + '?' + THIS-OBJECT:urlEncodedParams(). /** Add Query String to **/
        END.

        chHTTPRequestHeader = SUBSTITUTE('&1 &2 HTTP/&3' + {&CRLF},
                                         TRIM(THIS-OBJECT:HttpMethod),
                                         chPath ,
                                         TRIM(THIS-OBJECT:HttpVersion)).


        /** Output the content Length if the ContentType 'application/x-www-form-urlencoded'. **/
        IF THIS-OBJECT:ContentType EQ 'application/x-www-form-urlencoded':U THEN
        DO:
            THIS-OBJECT:AddHeader('Content-Length', STRING( LENGTH( urlEncodedParams() )) ).
            THIS-OBJECT:ADDHEADER('Content-Type', THIS-OBJECT:ContentType).        
        END.

        /** Calculate the content length for a post..**/
        IF THIS-OBJECT:ContentType EQ 'multipart/form-data':U THEN
        DO:
            DEFINE VARIABLE inContentLength AS INTEGER     NO-UNDO.

            inContenTLENGTH = 0.
            
            FOR EACH ttHttpRequestParam:
                inContentLength = inContenTLENGTH + LENGTH('--' + THIS-OBJECT:Boundary + {&CRLF},'RAW'). 
                inContenTLENGTH = inContenTLENGTH + LENGTH(SUBSTITUTE('Content-Disposition: form-data; name="&1"' + {&CRLF} + {&CRLF},ttHttpRequestParam.HttpParamName), 'RAW').
                inContenTLENGTH = inContenTLENGTH + LENGTH(ttHttpRequestParam.HttpParamValue).
                inContenTLENGTH = inContenTLENGTH + 2. /** 2 Bytes for CRLF **/
            END.


            FOR EACH ttFormData:
                inContentLength = inContenTLENGTH + LENGTH('--' + THIS-OBJECT:Boundary + {&CRLF},'RAW'). 
                inContenTLENGTH = inContenTLENGTH + LENGTH(SUBSTITUTE('Content-Disposition: form-data; name="&1"; filename="&2"' + {&CRLF},
                                                                      ttFormData.FormName,
                                                                      ttFormData.RemoteFilename), 'RAW').
                inContentLength = inContenTLENGTH + LENGTH(SUBSTITUTE('Content-Type: &1',
                                                                      ttFormData.ContentType
                                                                      ) + {&CRLF},'RAW'). 

                IF ttFormData.ContenTTYPE NE 'text/plain' THEN
                    inContentLength = inContenTLENGTH + LENGTH('Content-Transfer-Encoding: binary' + {&CRLF} + {&CRLF},'RAW').
                ELSE
                    inContentLength = inContenTLENGTH + 2. /** 2 Bytes for CRLF **/

                inContenTLENGTH = inContenTLENGTH + ttFormData.BloBSIZE.
                inContenTLENGTH = inContenTLENGTH + 2. /** 2 Bytes for CRLF **/
            END.

            inContentLength = inContenTLENGTH + LENGTH('--' + THIS-OBJECT:Boundary + '--','RAW'). 

            THIS-OBJECT:AddHeader('Content-Length', STRING( inContentLength )).
            THIS-OBJECT:ADDHEADER('Content-Type', SUBSTITUTE('multipart/form-data; boundary=&1' + {&CRLF} + {&CRLF}, 
                                                             THIS-OBJECT:Boundary)
                                  ).
        END.

        

        FOR EACH ttHttpRequestHeader
            BY ttHttpRequestHeader.HttpHeaderIndex:
            
            chHTTPRequestHeader = SUBSTITUTE('&1&2: &3' + {&CRLF},
                                             chHTTPRequestHeader,
                                             TRIM(ttHttpRequestHeader.HttpHeaderName),
                                             TRIM(ttHttpRequestHeader.HttpHeaderValue)
                                             ).
        END.

/*         chHTTPRequestHeader = SUBSTITUTE('&1Content-Type: &2' + {&CRLF}, */
/*                                          chHTTPRequestHeader,            */
/*                                          THIS-OBJECT:ContentType).       */

        RETURN chHTTPRequestHeader + {&CRLF}. /** END OF MIMI HTTP HEADER...**/
         
    END METHOD.
    
    METHOD VOID AddParam(INPUT pchParamName  AS CHARACTER,
                         INPUT pchParamValue AS CHARACTER):
        /** 
            Adds a request query parameter (name/value pair) to the HTTP request. 
            The name and value strings passed to this method should not be URL encoded.
        **/

            THIS-OBJECT:NumParams = THIS-OBJECT:NumParams + 1.

            CREATE ttHttpRequestParam.

            ASSIGN
                ttHttpRequestParam.HttpParamIndex   = THIS-OBJECT:NumParams
                ttHttpRequestParam.HttpParamName    = pchParamName   
                ttHttpRequestParam.HttpParamValue   = pchParamValue
                ttHttpRequestParam.HttpParamEncoded = SUBSTITUTE('&1=&2',
                                                                 THIS-OBJECT:URL-ENCODE(ttHttpRequestParam.HttpParamName,'query'),
                                                                 THIS-OBJECT:URL-ENCODE(ttHttpRequestParam.HttpParamValue,'query')
                                                                 )
                ttHttpRequestParam.HttpParamSize    = LENGTH(ttHttpRequestParam.HttpParamEncoded,"RAW").

    END METHOD.

    METHOD VOID RemoveParam(INPUT pchParamName AS CHARACTER):
        /** 
            Removes a all matching HTTP request parameter by name.
        **/
        FOR EACH  ttHttpRequestParam
            WHERE ttHttpRequestParam.HttpParamName EQ pchParamName:

            DELETE ttHttpRequestParam.
        END.

        THIS-OBJECT:NumParams = 0.

        /** Re-aline the numbering index **/
        FOR EACH ttHttpRequestParam
            BY ttHttpRequestParam.HttpParamIndex:
            
            THIS-OBJECT:NumParams = THIS-OBJECT:NumParams + 1.

            ASSIGN 
                ttHttpRequestParam.HttpParamIndex   = THIS-OBJECT:NumParams.
        END.

    END METHOD.

    METHOD PUBLIC CHARACTER getParamName(INPUT pchParamIndex AS INTEGER):
        /** 
            Removes a single HTTP request parameter by name.
            
        DEFINE PRIVATE TEMP-TABLE ttHttpRequestParam NO-UNDO
        FIELD HttpParamName    AS CHARACTER 
        FIELD HttpParamValue   AS CHARACTER
        FIELD HttpParamIndex   AS INTEGER
        FIELD HttpParamEncoded AS CHARACTER
        FIELD HttpParamSize    AS INTEGER
        INDEX idxParamName IS UNIQUE PRIMARY
            HttpParamName
        INDEX idxParamIndex 
            HttpParamIndex.
            
        **/
        FIND ttHttpRequestParam
            WHERE ttHttpRequestParam.HttpParamIndex =  pchParamIndex
            NO-ERROR.

        RETURN (IF AVAILABL ttHttpRequestParam THEN ttHttpRequestParam.HttpParamName ELSE '').

    END METHOD.

    METHOD PUBLIC CHARACTER getParamValue(INPUT pchParamIndex AS INTEGER):
        /** 
            Return a single HTTP request parameter by index value.
            
        DEFINE PRIVATE TEMP-TABLE ttHttpRequestParam NO-UNDO
        FIELD HttpParamName    AS CHARACTER 
        FIELD HttpParamValue   AS CHARACTER
        FIELD HttpParamIndex   AS INTEGER
        FIELD HttpParamEncoded AS CHARACTER
        FIELD HttpParamSize    AS INTEGER
        INDEX idxParamName IS UNIQUE PRIMARY
            HttpParamName
        INDEX idxParamIndex 
            HttpParamIndex.
            
        **/
        FIND ttHttpRequestParam
            WHERE ttHttpRequestParam.HttpParamIndex EQ pchParamIndex
            NO-ERROR.

        RETURN (IF AVAILABL ttHttpRequestParam THEN ttHttpRequestParam.HttpParamValue ELSE '').

    END METHOD.

    METHOD PUBLIC VOID RemoveAllParams():
        /**
            Removes all request parameters.
        **/
        THIS-OBJECT:NumParams = 0.

        EMPTY TEMP-TABLE  ttHttpRequestParam. 

    END METHOD.

    METHOD PUBLIC LONGCHAR urlEncodedParams():
            
        DEFINE VARIABLE chPostData AS LONGCHAR   NO-UNDO INITIAL ''.

        FOR EACH ttHttpRequestParam
            BREAK BY ttHttpRequestParam.HttpParamIndex:

            chPostData = chPostData + ttHttpRequestParam.HttpParamEncoded.

            IF NOT LAST(ttHttpRequestParam.HttpParamIndex) THEN
                chPostData = chPostData + '&':U.

        END.

        RETURN chPostData.

    END METHOD. 
    

    METHOD PRIVATE CHARACTER url-encode (INPUT p_value AS CHARACTER,
                                         INPUT p_enctype AS CHARACTER):
/****************************************************************************
Description: Encodes unsafe characters in a URL as per RFC 1738 section 2.2.
  <URL:http://ds.internic.net/rfc/rfc1738.txt>, 2.2
Input Parameters: Character string to encode, Encoding option where "query",
  "cookie", "default" or any specified string of characters are valid.
  In addition, all characters specified in the global variable url_unsafe
  plus ASCII values 0 <= x <= 31 and 127 <= x <= 255 are considered unsafe.
Returns: Encoded string  (unkown value is returned as blank)
Global Variables: url_unsafe, url_reserved
****************************************************************************/
  DEFINE VARIABLE hx          AS CHARACTER NO-UNDO INITIAL "0123456789ABCDEF":U.
  DEFINE VARIABLE encode-list AS CHARACTER NO-UNDO.
  DEFINE VARIABLE i           AS INTEGER   NO-UNDO.
  DEFINE VARIABLE c           AS INTEGER   NO-UNDO.



  DEFINE VARIABLE url_unsafe   AS CHARACTER NO-UNDO INITIAL "<>~"#%~{}|~\^~~[]`":U.

    /* Reserved characters that normally are not encoded in URL's */
     DEFINE VARIABLE url_reserved AS CHARACTER NO-UNDO INITIAL "~;/?:@=&":U.
     
      /* Don't bother with blank or unknown  */
      IF LENGTH(p_value) = 0 OR p_value = ? THEN 
        RETURN "".
       
      /* What kind of encoding should be used? */
      CASE p_enctype:
        WHEN "query":U THEN              /* QUERY_STRING name=value parts */
          encode-list = url_unsafe + url_reserved + "+":U.
        WHEN "cookie":U THEN             /* Persistent Cookies */
          encode-list = url_unsafe + " ,~;":U.
        WHEN "default":U OR WHEN "" THEN /* Standard URL encoding */
          encode-list = url_unsafe.
        OTHERWISE
          encode-list = url_unsafe + p_enctype.   /* user specified ... */
      END CASE.
    
      /* Loop through entire input string */
      ASSIGN i = 0.
      DO WHILE TRUE:
        ASSIGN
          i = i + 1
          /* ASCII value of character using single byte codepage */
          c = ASC(SUBSTRING(p_value, i, 1, "RAW":U), "1252":U, "1252":U).
        IF c <= 31 OR c >= 127 OR INDEX(encode-list, CHR(c)) > 0 THEN DO:
          /* Replace character with %hh hexidecimal triplet */
          SUBSTRING(p_value, i, 1, "RAW":U) =
            "%":U +
            SUBSTRING(hx, INTEGER(TRUNCATE(c / 16, 0)) + 1, 1, "RAW":U) + /* high */
            SUBSTRING(hx, c MODULO 16 + 1, 1, "RAW":U).             /* low digit */
          ASSIGN i = i + 2.   /* skip over hex triplet just inserted */
        END.
        IF i = LENGTH(p_value,"RAW":U) THEN LEAVE.
      END.
        
        /** Spaces are replaced with + rather than %20 **/
        p_value = REPLACE(p_value,' ', '+').

        RETURN p_value.
    END METHOD.  /* url-encode */

     

END CLASS.

