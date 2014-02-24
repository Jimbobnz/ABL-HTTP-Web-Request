USING co.dsg.http.*.

CLASS co.dsg.http.httpResponce:

    &SCOPED-DEFINE Http-NEWLINE CHR(13) + CHR(10)

    DEFINE PUBLIC PROPERTY Cookie     AS CLASS HttpCookies  NO-UNDO GET. PRIVATE SET. 
    
    DEFINE PROPERTY URL                 AS CHARACTER INITIAL '/' NO-UNDO GET. SET . 
    DEFINE PROPERTY hostname            AS CHARACTER             NO-UNDO GET. SET . 
    DEFINE PROPERTY STARTINGCONTENTAT   AS INTEGER INITIAL 1     NO-UNDO GET. PRIVATE SET. 
    DEFINE PROPERTY HttpResponceCode    AS INTEGER               NO-UNDO GET. PRIVATE SET. 
    DEFINE PROPERTY HttpResponceStatus  AS CHARACTER             NO-UNDO GET. PRIVATE SET. 
    DEFINE PROPERTY HttpResponceString  AS CHARACTER             NO-UNDO GET. PRIVATE SET. 
    DEFINE PROPERTY Header  AS MEMPTR                NO-UNDO GET. PRIVATE SET. 
    DEFINE PROPERTY Body    AS MEMPTR                NO-UNDO GET. PRIVATE SET. 
    

    DEFINE PRIVATE TEMP-TABLE ttHttpResponces NO-UNDO
        FIELD FieldName   AS CHARACTER
        FIELD FeildValues AS CHARACTER
        INDEX idxFieldName AS UNIQUE PRIMARY
            FieldName. 

    DEFINE TEMP-TABLE ttChunkedDATA NO-UNDO
        FIELD Order         AS INTEGER
        FIELD ChunkSize     AS INTEGER
        FIELD ChunkSizeHex  AS CHARACTER
        FIELD BLOBDATA AS BLOB
        INDEX idxOrder is UNIQUE PRIMARY
            Order.
    
    CONSTRUCTOR httpResponce():
        
    END CONSTRUCTOR.     

    CONSTRUCTOR httpResponce(INPUT Cookie AS CLASS HttpCookies):
        THIS-OBJECT:Cookie = Cookie.
    END CONSTRUCTOR.     

    DESTRUCTOR httpResponce():
        Cookie:SaveCookies().
    END DESTRUCTOR.     
    
    METHOD VOID EmptyHeaders():
        EMPTY TEMP-TABLE ttHttpResponces.
    END.

    METHOD PRIVATE MEMPTR DeCompressBuffer (INPUT InputBuffer AS MEMPTR):

      /* DeCompress a piece of memory and return a pointer to the decompressed data,
         in case of failure the size of decompressed data = -1
      */
          DEFINE VARIABLE OutputBuffer AS MEMPTR    NO-UNDO.
          DEFINE VARIABLE retcode AS INT NO-UNDO.

          COPY-LOB FROM InputBuffer TO FILE 'CompressedData.gz'.

          RUN src/uncompress.p (INPUT InputBuffer,
                                OUTPUT OutputBuffer,
                                OUTPUT retcode).

          MESSAGE retcode GET-SIZE(InputBuffer) GET-SIZE(OutputBuffer)
              VIEW-AS alert-box info.
  


        RETURN OutputBuffer.
    END METHOD. /* DeCompress Buffer */

    METHOD PRIVATE INTEGER HexToInt (INPUT chHEX AS LONGCHAR):

        RETURN THIS-OBJECT:HexToInt(INPUT STRING(chHEX) ).
    END METHOD.

    METHOD PRIVATE INTEGER HexToInt (INPUT chHEX AS CHARACTER):
    
        DEFINE VARIABLE ININTEGER   AS INTEGER NO-UNDO INITIAL 0.
        DEFINE VARIABLE inj         AS INTEGER NO-UNDO.
    
        chHEX = CAPS(chHEX).
        DO inj = 1 TO LENGTH(chHEX):
            IF CAN-DO("0,1,2,3,4,5,6,7,8,9", (SUBSTRING(chHEX, inj, 1))) THEN
                ININTEGER = ININTEGER + INT(SUBSTRING(chHEX, inj, 1)) * EXP(16, (LENGTH(chHEX) - inj)).
            ELSE
                ININTEGER = ININTEGER + (KEYCODE(SUBSTRING(chHEX, inj, 1)) - KEYCODE("A") + 10) * EXP(16, (LENGTH(chHEX) - inj)).
        END.

        RETURN ININTEGER.
    END METHOD.

    METHOD CHARACTER HEADER():
        DEFINE VARIABLE chHeaders AS CHARACTER   NO-UNDO.

        FOR EACH ttHttpResponces
            BREAK BY ttHttpResponces.FieldName:

            chHeaders = chHeaders + ttHttpResponces.FieldName.
            
            IF NOT LAST(ttHttpResponces.FieldName) THEN
                chHeaders = chHeaders + ','.
        END.

        RETURN chHeaders.
    END METHOD.

    /** Get Field Header **/
    METHOD CHARACTER HEADER (INPUT pcFieldName AS CHARACTER):

        /** If the Unknown value (?) is specified, the 
            method returns a list of all header names. **/
        IF pcFieldName EQ ? THEN
            RETURN THIS-OBJECT:HEADER().
        ELSE
        DO:
            FIND ttHttpResponces WHERE
                 ttHttpResponces.FieldName EQ pcFieldName
                NO-ERROR.

            IF AVAILABLE ttHttpResponces THEN
                RETURN ttHttpResponces.FeildValues.
            ELSE
                RETURN ''.
        END.
    END METHOD.

    /** Set/Delete Field Header **/
    METHOD ROWID HEADER (INPUT pcFieldName  AS CHARACTER,
                         INPUT pcFieldValue AS CHARACTER):

        FIND ttHttpResponces WHERE
            ttHttpResponces.FieldName EQ pcFieldName
            NO-ERROR.

        IF NOT AVAILABLE ttHttpResponces THEN
        DO:
            CREATE ttHttpResponces.
            ASSIGN
                ttHttpResponces.FieldName = pcFieldName.
        END.

        IF pcFieldValue EQ '' THEN
            DELETE ttHttpResponces.
        ELSE
            ASSIGN
                ttHttpResponces.FeildValues = pcFieldValue.
            
        TEMP-TABLE ttHttpResponces:WRITE-XML('file','HTTPHEADERS.xml',true).        

        RETURN (IF AVAILABLE ttHttpResponces THEN ROWID(ttHttpResponces) ELSE ?).

    END METHOD.

    /** Append Header value to an existing header...**/
    METHOD ROWID HEADER (INPUT priRowID    AS ROWID,
                         INPUT pcFieldValue AS CHARACTER):

        FIND ttHttpResponces WHERE
            ROWID(ttHttpResponces) EQ priRowID
            NO-ERROR.

        IF AVAILABLE ttHttpResponces THEN
        DO:
            ASSIGN
              ttHttpResponces.FeildValues = ttHttpResponces.FeildValues + pcFieldValue.
            RETURN ROWID(ttHttpResponces).

        END.
        ELSE
            RETURN ?.
    END METHOD.
    


    METHOD PUBLIC VOID ParseHttpResponce
        (   INPUT pchHostname AS CHARACTER,
            INPUT mpHttpData  AS MEMPTR):

        DEFINE VARIABLE inLoop              AS INTEGER     NO-UNDO.
        DEFINE VARIABLE chHeaderLine        AS CHARACTER   NO-UNDO.
        DEFINE VARIABLE inDelimiterPos      AS INTEGER     NO-UNDO.
        DEFINE VARIABLE riHeaderROWID       AS ROWID       NO-UNDO.
            
        THIS-OBJECT:EmptyHeaders().
        THIS-OBJECT:STARTINGCONTENTAT = 0.

        IF GET-SIZE(mpHttpData) EQ 0 THEN
            RETURN.

        HEADER-PARSE:
        DO inLoop = 1 TO GET-SIZE(mpHttpData) - 1:

            /** Look for end of the header block...**/
            IF GET-BYTE(mpHttpData,inLoop)     EQ 13 AND
               GET-BYTE(mpHttpData,inLoop + 1) EQ 10 AND 
               GET-BYTE(mpHttpData,inLoop + 2) EQ 13 AND
               GET-BYTE(mpHttpData,inLoop + 3) EQ 10 THEN
            DO:
                THIS-OBJECT:STARTINGCONTENTAT = inLoop + 4 .
                    LEAVE HEADER-PARSE.
            END.

            IF GET-BYTE(mpHttpData,inLoop)     EQ 13 AND
               GET-BYTE(mpHttpData,inLoop + 1) EQ 10 THEN
            DO:
                chHeaderLine = GET-STRING(mpHttpData, STARTINGCONTENTAT + 1, (inLoop - (STARTINGCONTENTAT - 1)) ).
                THIS-OBJECT:STARTINGCONTENTAT = inLoop + 1.

                /** CHECK FOR THE Http Responce Header. *Should be the first Line..**/
                IF chHeaderLine BEGINS 'HTTP/':U  THEN
                DO:
                   
                    ASSIGN
                        THIS-OBJECT:HttpResponceString = chHeaderLine           
                        chHeaderLine                   = TRIM(SUBSTRING(chHeaderLine, 9))     /** Strip of the Http part and remove spaces.**/
                        THIS-OBJECT:HttpResponceCode   = INTEGER(SUBSTRING(chHeaderLine,1,3)) /** Extract the Responce Code **/
                        chHeaderLine                   = TRIM(SUBSTRING(chHeaderLine, 4))     /** Remove the Responce code and remoce spaces. **/
                        THIS-OBJECT:HttpResponceStatus = TRIM(chHeaderLine).                  

                    NEXT HEADER-PARSE. 
                END.


                /** Looking for lines begining with spaces or tabs. Append the header line to the last created header. **/
                IF chHeaderLine BEGINS CHR(32) OR
                   chHeaderLine BEGINS CHR(9) THEN
                DO:
                    IF riHeaderROWID EQ ? THEN
                        riHeaderROWID = THIS-OBJECT:HEADER(INPUT riHeaderROWID,
                                                           INPUT chHeaderLine).
                    
                    NEXT HEADER-PARSE.

                END.
                ELSE
                DO:

                    /** Split the header line into name,value pairs. **/
                    inDelimiterPos = INDEX(chHeaderLine,':').
                    
                    IF LOGICAL(inDelimiterPos) THEN
                    DO:
                        DEFINE VARIABLE chHeaderName  AS CHARACTER   NO-UNDO.
                        DEFINE VARIABLE chHeaderValue AS CHARACTER   NO-UNDO.
    
                        ASSIGN
                            chHeaderName  = SUBSTRING(chHeaderLine, 1, inDelimiterPos - 1)
                            chHeaderValue = SUBSTRING(chHeaderLine, inDelimiterPos + 1)
                            chHeaderValue = TRIM(chHeaderValue).

/*                         MESSAGE chHeaderName chHeaderValue. */
                            
                        IF chHeaderName EQ 'Set-Cookie':U THEN
                            Cookie:ImportCookie(INPUT pchHostname,
                                                INPUT chHeaderValue).
                        ELSE
                            riHeaderROWID = THIS-OBJECT:HEADER(INPUT chHeaderName,
                                                               INPUT chHeaderValue).
                    END.

                    NEXT HEADER-PARSE.
                END.
            END.
        END.    /** END of HEADER-PARSE block.**/

        /** Save All Cookie Information to an XML file.**/
        Cookie:SaveCookies().

/*         IF THIS-OBJECT:STARTINGCONTENTAT GT GET-SIZE(mpHttpData) THEN */
/*             THIS-OBJECT:STARTINGCONTENTAT = GET-SIZE(mpHttpData).     */

        COPY-LOB FROM OBJECT mpHttpData TO FILE 'RAWHTTPDATA.txt'.

        IF THIS-OBJECT:STARTINGCONTENTAT GT 0 THEN
        DO:
            COPY-LOB FROM OBJECT mpHttpData STARTING AT 1 FOR THIS-OBJECT:STARTINGCONTENTAT - 4  TO THIS-OBJECT:Header.
            COPY-LOB FROM OBJECT mpHttpData STARTING AT (THIS-OBJECT:STARTINGCONTENTAT )         TO THIS-OBJECT:Body.


            /** Handle decompression GZIP **/
             IF THIS-OBJECT:HEADER('Content-Encoding') EQ 'gzip':U THEN
                THIS-OBJECT:Body = THIS-OBJECT:DeCompressBuffer(INPUT THIS-OBJECT:Body).
             
            /** Handle Chunked Content..**/
            IF THIS-OBJECT:HEADER('Content-Length')    EQ '' AND
               THIS-OBJECT:HEADER('Transfer-Encoding') EQ 'chunked':U THEN
            DO: 

                DEFINE VARIABLE objUnChunkData AS CLASS httpUnChunkData NO-UNDO.

                objUnChunkData = NEW httpUnChunkData().

                THIS-OBJECT:Body = objUnChunkData:Filter( THIS-OBJECT:Body).
            END.

        END.

        /** free up some data.**/
        SET-SIZE(mpHttpData) = 0. 
        
    END METHOD.

END CLASS.
