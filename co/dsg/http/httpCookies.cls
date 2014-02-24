/* httpCookies.cls

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

CLASS co.dsg.http.httpCookies.

    DEFINE PUBLIC PROPERTY HasCookies AS LOGICAL NO-UNDO GET. PRIVATE SET. 

    DEFINE PRIVATE TEMP-TABLE ttSessionCookies NO-UNDO SERIALIZE-NAME 'CookieJar'
        FIELD Host          AS CHARACTER
        FIELD CookieName    AS CHARACTER
        FIELD CookieValue   AS CHARACTER
        FIELD Domain        AS CHARACTER
        FIELD Path          AS CHARACTER
        FIELD Expires       AS CHARACTER
        FIELD Secure        AS LOGICAL INITIAL FALSE
        FIELD HttpOnly      AS LOGICAL INITIAL FALSE
        INDEX idxHostCookies IS PRIMARY UNIQUE
            Host
            CookieName
            CookieValue.

    DEFINE PRIVATE TEMP-TABLE ttPersistentCookies  SERIALIZE-NAME 'CookieJar' LIKE ttSessionCookies.

    CONSTRUCTOR httpCookies():

    END CONSTRUCTOR.

    METHOD PUBLIC LOGICAL LoadCookies():

        /** Load all the Persistent Cookies**/
        TEMP-TABLE ttSessionCookies:READ-XML('FILE','CookieJar.xml','EMPTY',?,?) NO-ERROR.
        RETURN TEMP-TABLE ttSessionCookies:HAS-RECORDS.        
    END METHOD.

    METHOD PUBLIC LOGICAL SaveCookies():
        
        /** Only Persistent Cookies can be saved to the 
            Cookie Jar. All other cookies are sessional. **/

        EMPTY TEMP-TABLE ttPersistentCookies.         

        FOR EACH ttSessionCookies
            WHERE ttSessionCookies.Expires NE '':

            CREATE ttPersistentCookies.

            BUFFER-COPY ttSessionCookies TO ttPersistentCookies.
        END.

        TEMP-TABLE ttPersistentCookies:WRITE-XML('FILE','CookieJar.xml',TRUE) NO-ERROR.
        RETURN TEMP-TABLE ttPersistentCookies:HAS-RECORDS.        
    END METHOD.

    METHOD CHARACTER GetCookies(INPUT pchHost   AS CHARACTER,
                                INPUT pchPath   AS CHARACTER,
                                INPUT plgSecure AS LOGICAL ):

        MESSAGE 
            pchHost   
            pchPath   
            plgSecure 
            VIEW-AS ALERT-BOX INFO.

        DEFINE VARIABLE chCookies AS CHARACTER   NO-UNDO.

        FOR EACH ttSessionCookies WHERE
            ttSessionCookies.host EQ pchHost AND
            pchPath               MATCHES ttSessionCookies.Path + '*'  AND
            (ttSessionCookies.Secure EQ plgSecure OR ttSessionCookies.Secure EQ FALSE)
            BREAK BY ttSessionCookies.CookieName:
            
            chCookies = chCookies + SUBSTITUTE("&1=&2",
                                               ttSessionCookies.CookieName,
                                               ttSessionCookies.CookieValue).

            IF NOT LAST(ttSessionCookies.CookieName) THEN
                chCookies = chCookies + '; '.
        END.

        RETURN chCookies.
    END METHOD.

    METHOD CHARACTER GetCookies( ):

        DEFINE VARIABLE chCookies AS CHARACTER   NO-UNDO.

        FOR EACH ttSessionCookies
            BREAK BY ttSessionCookies.CookieName:
            
            chCookies = chCookies + SUBSTITUTE("&1=&2",
                                               ttSessionCookies.CookieName,
                                               ttSessionCookies.CookieValue).

            IF NOT LAST(ttSessionCookies.CookieName) THEN
                chCookies = chCookies + '; '.
        END.

        RETURN chCookies.
    END METHOD.

    METHOD VOID ImportCookie
        (INPUT pchHostname AS CHARACTER,
         INPUT pchCookie   AS CHARACTER):

        DEFINE VARIABLE inCookieSegment AS INTEGER     NO-UNDO.
        DEFINE VARIABLE chCookieSegment AS CHARACTER   NO-UNDO.
        DEFINE VARIABLE chCookieName    AS CHARACTER   NO-UNDO.
        DEFINE VARIABLE chCookieValue   AS CHARACTER   NO-UNDO.
        
        COOKIE-ENTRY:
        DO inCookieSegment = 1 TO NUM-ENTRIES(pchCookie,';'):

            chCookieSegment = TRIM(ENTRY(inCookieSegment, pchCookie, ';')).

            IF inCookieSegment EQ 1 THEN
            DO:
                ASSIGN
                    chCookieName  = TRIM(ENTRY(1, chCookieSegment, '=')) 
                    chCookieValue = TRIM(SUBSTRING( chCookieSegment, INDEX(chCookieSegment,'=') + 1 )).

                IF chCookieValue EQ "" THEN
                DO:
                    FOR EACH  ttSessionCookies 
                        WHERE ttSessionCookies.host        EQ pchHostname  AND
                              ttSessionCookies.CookieName  EQ chCookieName:
                        
                        DELETE ttSessionCookies.
                    END.

                    LEAVE COOKIE-ENTRY.
                END.
                ELSE
                DO:
                    FIND  ttSessionCookies 
                    WHERE ttSessionCookies.host        EQ pchHostname  AND
                          ttSessionCookies.CookieName  EQ chCookieName AND
                          ttSessionCookies.CookieValue EQ chCookieValue
                        NO-ERROR.
    
                    IF NOT AVAILABLE ttSessionCookies THEN
                        CREATE ttSessionCookies.
    
                    /** Cannot use ENTRY Function as value could contain '=' symbol.**/
                    ASSIGN
                        ttSessionCookies.host        = TRIM(pchHostname)
                        ttSessionCookies.CookieName  = TRIM(chCookieName)
                        ttSessionCookies.CookieValue = TRIM(chCookieValue). 
                END.

                NEXT COOKIE-ENTRY.
            END.

            CASE TRUE:
                WHEN chCookieSegment EQ 'HttpOnly':U THEN
                    ttSessionCookies.HttpOnly          = TRUE.
                WHEN chCookieSegment EQ 'Secure':U THEN
                    ttSessionCookies.Secure            = TRUE.
                WHEN chCookieSegment MATCHES 'Domain=*':U THEN
                    ttSessionCookies.Domain            = ENTRY(2, chCookieSegment, '=').
                WHEN chCookieSegment MATCHES 'Path=*':U THEN
                    ttSessionCookies.Path              = ENTRY(2, chCookieSegment, '=').
                WHEN chCookieSegment MATCHES 'Expires=*':U THEN
                    ASSIGN
                        ttSessionCookies.Expires       = ENTRY(2, chCookieSegment, '=').
            END CASE.

            IF ttSessionCookies.COOKIEVALUE EQ '' THEN
                DELETE ttSessionCookies.
        END.
        
        THIS-OBJECT:HasCookies = TEMP-TABLE ttSessionCookies:HAS-RECORDS.

    END METHOD.

    

END CLASS.
