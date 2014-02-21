CLASS src.httpUnChunkData:

    CONSTRUCTOR httpUnChunkData():
  
    END CONSTRUCTOR.

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

    METHOD PRIVATE INTEGER strpos(INPUT mpDataSource AS memptr,
                                  INPUT chTarget AS CHARACTER):

        RETURN THIS-OBJECT:strpos(INPUT mpDataSource,
                                  INPUT chTarget,
                                  INPUT 1).
    END METHOD.

    METHOD PRIVATE INTEGER strpos(INPUT mpDataSource AS memptr,
                                  INPUT chTarget     AS CHARACTER,
                                  INPUT inStartingPos  AS INTEGER):

        DEFINE VARIABLE inLoop       AS INTEGER     NO-UNDO.
        DEFINE VARIABLE inStringPos  AS INTEGER     NO-UNDO.
        DEFINE VARIABLE inSourceSize AS INTEGER     NO-UNDO.

        inSourceSize = GET-SIZE(mpDataSource).
        
        IF inStartingPos GT inSourceSize THEN
            RETURN ?.

        STRING-LOOP:
        DO inLoop = inStartingPos TO inSourceSize:

            IF GET-STRING(mpDataSource, inLoop, LENGTH(chTarget)) EQ chTarget THEN 
            DO:
                inStringPos = inLoop.
                LEAVE STRING-LOOP.
            END.
        END.

        RETURN inStringPos.
    END METHOD.

    METHOD PUBLIC MEMPTR Filter(INPUT mpDataSource AS MEMPTR):

        DEFINE VARIABLE inStartingAtPos         AS INTEGER     NO-UNDO INITIAL 1.
        DEFINE VARIABLE inChunkRemaining AS INTEGER     NO-UNDO.
        DEFINE VARIABLE inDelimiterPos      AS INTEGER     NO-UNDO.
        DEFINE VARIABLE chChunkedData    AS CHARACTER   NO-UNDO.
        DEFINE VARIABLE chChunkHEXSize    AS CHARACTER   NO-UNDO.
        DEFINE VARIABLE mpDataTemp       AS MEMPTR      NO-UNDO.
        DEFINE VARIABLE mpDataTarget     AS MEMPTR      NO-UNDO.
        DEFINE VARIABLE mpDataSwap       AS MEMPTR      NO-UNDO.
        
        SET-SIZE(mpDataTarget) = 0.

        UNCHUNK-FILTER:
        DO WHILE inStartingAtPos LT GET-SIZE(mpDataSource):

            IF inChunkRemaining EQ 0 THEN
            DO:
                inDelimiterPos = strpos(INPUT mpDataSource,
                                        INPUT CHR(13) + CHR(10),
                                        INPUT inStartingAtPos).

                chChunkedData    = GET-STRING(mpDataSource, inStartingAtPos, (inDelimiterPos - inStartingAtPos) ).
                chChunkHEXSize   = TRIM(chChunkedData).
                inChunkRemaining = THIS-OBJECT:HexToInt(INPUT chChunkHEXSize).

                MESSAGE inStartingAtPos inDelimiterPos chChunkHEXSize inChunkRemaining 'bytes' ROUND((inDelimiterPos / GET-SIZE(mpDataSource) * 100), 2)'%'.

                IF inChunkRemaining EQ 0 THEN
                    LEAVE UNCHUNK-FILTER.

                inStartingAtPos = inDelimiterPos + 2.
            END.

            SET-SIZE(mpDataTemp) = 0.

            COPY-LOB FROM OBJECT mpDataSource STARTING AT inStartingAtPos FOR inChunkRemaining TO OBJECT mpDataTemp. 

            inStartingAtPos = inStartingAtPos + GET-SIZE(mpDataTemp).

            IF GET-SIZE(mpDataTemp) EQ inChunkRemaining THEN 
                inStartingAtPos = inStartingAtPos + 2.

            inChunkRemaining = inChunkRemaining - GET-SIZE(mpDataTemp).
            
            /** Hack to to append data to an exisintg MEMPTR **/
            SET-SIZE(mpDataSwap) = 0.
            SET-SIZE(mpDataSwap) = GET-SIZE(mpDataTarget) + GET-SIZE(mpDataTemp). 
            
            COPY-LOB FROM OBJECT mpDataTarget TO OBJECT mpDataSwap OVERLAY AT 1.
            COPY-LOB FROM OBJECT mpDataTemp   TO OBJECT mpDataSwap OVERLAY AT GET-SIZE(mpDataTarget) + 1.

            SET-SIZE(mpDataTarget) = 0.
            SET-SIZE(mpDataTarget) = GET-SIZE(mpDataSwap).
            COPY-LOB FROM OBJECT mpDataSwap TO OBJECT mpDataTarget.

            SET-SIZE(mpDataSwap) = 0.
            SET-SIZE(mpDataTemp)  = 0.

        END.
        
        RETURN mpDataTarget.

    END METHOD.
END CLASS.
