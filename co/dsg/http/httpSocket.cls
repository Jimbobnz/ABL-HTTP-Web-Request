/* httpSocket.p

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


CLASS co.dsg.http.httpSocket:
    
    DEFINE VARIABLE hnClientSocket             AS HANDLE NO-UNDO.
    
    CONSTRUCTOR httpSocket():
        CREATE SOCKET hnClientSocket.
        
        /** Debug log.**/
        OS-DELETE 'Socket-out.log'.

    END CONSTRUCTOR.

    DESTRUCTOR httpSocket():
        IF VALID-HANDLE(hnClientSocket) THEN
        DO:

            IF hnClientSocket:CONNECTED() THEN
                hnClientSocket:DISCONNECT().

            DELETE OBJECT hnClientSocket.
        END.
    END DESTRUCTOR.

    METHOD LOGICAL CONNECT
        (INPUT pchHost   AS CHARACTER,
         INPUT pinPort   AS INTEGER,
         INPUT plgSecure AS LOGICAL):

         DEFINE VARIABLE chConnect AS CHARACTER   NO-UNDO.
        
         IF plgSecure THEN
             MESSAGE 'Connecting over SSL'
                VIEW-AS alert-box info.
        
         IF pchHost EQ '' OR pinPort EQ 0 THEN
             RETURN FALSE.

        chConnect = SUBSTITUTE("-H &1 -S &2 &3",
                               pchHost,
                               pinPort,
                               (IF plgSecure THEN '-ssl' ELSE '')
                               ).
        /** Need to be a Property or Set Method**/
        hnClientSocket:SET-SOCKET-OPTION("SO-RCVTIMEO", '5').
            
        RETURN hnClientSocket:CONNECT(chConnect).

    END METHOD.
 
    METHOD LOGICAL CONNECTED():
        RETURN hnClientSocket:CONNECTED().
    END METHOD.
    
    METHOD PUBLIC LOGICAL WRITE (INPUT pchStringData AS CHARACTER):

        DEFINE VARIABLE lcStringData AS LONGCHAR   NO-UNDO.

        lcStringData = pchStringData.

        RETURN THIS-OBJECT:WRITE(INPUT lcStringData). 

    END METHOD.

    METHOD PUBLIC LOGICAL WRITE (INPUT pchStringData AS LONGCHAR):
    
        DEFINE VARIABLE mpData AS MEMPTR      NO-UNDO.

        SET-SIZE(mpData) = 0.
        COPY-LOB FROM pchStringData TO OBJECT mpData.

        RETURN THIS-OBJECT:WRITE(mpData).

    END METHOD.

    METHOD PUBLIC LOGICAL WRITE (INPUT pmpData AS MEMPTR):

        IF NOT VALID-HANDLE(hnClientSocket) OR
            NOT hnClientSocket:CONNECTED() THEN 
            RETURN FALSE.
            
        COPY-LOB FROM OBJECT pmpData TO FILE 'Socket-out.log' APPEND.

        hnClientSocket:WRITE(pmpData, 1, GET-SIZE(pmpData)).

        IF hnClientSocket:BYTES-WRITTEN EQ 0 THEN 
            RETURN FALSE.

        IF hnClientSocket:BYTES-WRITTEN NE GET-SIZE(pmpData) THEN
            RETURN FALSE.

        RETURN TRUE.

    END METHOD.

    METHOD PUBLIC MEMPTR READ():
        
        DEFINE VARIABLE inBytesAvail    AS INTEGER  NO-UNDO.
        DEFINE VARIABLE lastBytes       AS INTEGER  NO-UNDO.
        DEFINE VARIABLE inIteration     AS INTEGER  NO-UNDO.
        DEFINE VARIABLE mpSocketBuffer  AS MEMPTR   NO-UNDO.
        DEFINE VARIABLE mpData          AS MEMPTR   NO-UNDO.
        DEFINE VARIABLE mpDataTemp      AS MEMPTR   NO-UNDO.

        &SCOPED-DEFINE TIMEOUTMS 3000

        IF NOT VALID-HANDLE(hnClientSocket) OR
           NOT hnClientSocket:CONNECTED() THEN 
            RETURN mpData.

        CONNECTED-BLOCK:
        DO WHILE hnClientSocket:CONNECTED():

            PROCESS EVENTS. 
    
            IF NOT hnClientSocket:CONNECTED() THEN
                LEAVE CONNECTED-BLOCK.
        
            inIteration = inIteration + 1.

            inBytesAvail = hnClientSocket:GET-BYTES-AVAILABLE().

            IF NOT LOGICAL(inBytesAvail) THEN
            DO:
                ETIME(YES).
                DO WHILE inBytesAvail = 0 AND ETIME < {&TIMEOUTMS}:
                    inBytesAvail = hnClientSocket:GET-BYTES-AVAILABLE().
                END.
            END.
    
            IF LOGICAL(inBytesAvail) THEN 
            DO:
        
                /*OK, there's something on the wire... Read it in*/    
                SET-SIZE(mpSocketBuffer) = 0.
                SET-BYTE-ORDER(mpSocketBuffer) = BIG-ENDIAN.
                SET-SIZE(mpSocketBuffer) = inBytesAvail.
            
                hnClientSocket:READ(mpSocketBuffer, 1, inBytesAvail, READ-EXACT-NUM).
                
                /** This is my solution to creating a dynamically increasing memory 
                    pointer as more and more data is streamed down the wire.
                 **/
        
                SET-SIZE(mpDataTemp) = 0.
                SET-SIZE(mpDataTemp) = GET-SIZE(mpData) + GET-SIZE(mpSocketBuffer).
        
                COPY-LOB FROM mpData         TO OBJECT mpDataTemp OVERLAY AT 1 NO-ERROR. /** DO NOT REMOVE OVERLAY STATMENT!! **/
                COPY-LOB FROM mpSocketBuffer TO OBJECT mpDataTemp OVERLAY AT GET-SIZE(mpData) + 1  NO-ERROR.
        
                SET-SIZE(mpData) = 0.
                SET-SIZE(mpData) = GET-SIZE(mpDataTemp).
        
                COPY-LOB FROM mpDataTemp TO OBJECT mpData.
                
                SET-SIZE(mpDataTemp) = 0.
                SET-SIZE(mpSocketBuffer) = 0.
            END.
        
            IF NOT hnClientSocket:CONNECTED() THEN
                LEAVE CONNECTED-BLOCK.
        END.

        RETURN mpData.
    END METHOD.

END CLASS.
