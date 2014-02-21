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

CLASS httpCookies.

    DEFINE PUBLIC PROPERTY HasCookies AS LOGICAL NO-UNDO GET. PRIVATE SET. 

    DEFINE PRIVATE TEMP-TABLE ttCookieJar NO-UNDO SERIALIZE-NAME 'CookieJar'
        FIELD COOKIENAME    AS CHARACTER
        FIELD COOKIEVALUE   AS CHARACTER
        FIELD Domain        AS CHARACTER
        FIELD Path          AS CHARACTER
        FIELD Expires       AS CHARACTER
        FIELD SessionCookie AS LOGICAL INITIAL TRUE
        FIELD Secure        AS LOGICAL INITIAL FALSE
        FIELD HttpOnly      AS LOGICAL INITIAL FALSE.

    DEFINE PRIVATE TEMP-TABLE ttSessionCookieJar NO-UNDO LIKE ttCookieJar.

    CONSTRUCTOR httpCookies():

    END CONSTRUCTOR.

    METHOD CHARACTER GetCookies( ):

        DEFINE VARIABLE chCookies AS CHARACTER   NO-UNDO.

        FOR EACH ttSessionCookieJar
            BREAK BY ttSessionCookieJar.COOKIENAME:
            
            chCookies = chCookies + SUBSTITUTE("&1=&2",
                                               ttSessionCookieJar.COOKIENAME,
                                               ttSessionCookieJar.COOKIEVALUE).

            IF NOT LAST(ttSessionCookieJar.COOKIENAME) THEN
                chCookies = chCookies + '; '.
        END.

        RETURN chCookies.
    END METHOD.

    METHOD VOID ImportCookie
        (INPUT pchCookie AS CHARACTER):

        DEFINE VARIABLE inCookieEntry     AS INTEGER     NO-UNDO.
        DEFINE VARIABLE chCookieComponent AS CHARACTER   NO-UNDO.

        DO inCookieEntry = 1 TO NUM-ENTRIES(pchCookie,';'):

            chCookieComponent  = TRIM(ENTRY(inCookieEntry, pchCookie, ';')).

            IF inCookieEntry EQ 1 THEN
            DO:

                FIND ttSessionCookieJar WHERE
                     ttSessionCookieJar.COOKIENAME  EQ ENTRY(1, chCookieComponent, '=') 
                    NO-ERROR.

                IF NOT AVAILABLE ttSessionCookieJar THEN
                    CREATE ttSessionCookieJar.

                ASSIGN
                    ttSessionCookieJar.COOKIENAME  = ENTRY(1, chCookieComponent, '=')
                    ttSessionCookieJar.COOKIEValue = ENTRY(2, chCookieComponent, '=').
                NEXT.
            END.

            CASE TRUE:
                WHEN chCookieComponent EQ 'HttpOnly':U THEN
                    ttSessionCookieJar.HttpOnly         = TRUE.
                WHEN chCookieComponent EQ 'Secure':U THEN
                    ttSessionCookieJar.Secure           = TRUE.
                WHEN chCookieComponent MATCHES 'Domain=*':U THEN
                    ttSessionCookieJar.Domain           = ENTRY(2, chCookieComponent, '=').
                WHEN chCookieComponent MATCHES 'Path=*':U THEN
                    ttSessionCookieJar.Path             = ENTRY(2, chCookieComponent, '=').
                WHEN chCookieComponent MATCHES 'Expires=*':U THEN
                    ASSIGN
                        ttSessionCookieJar.Expires       = ENTRY(2, chCookieComponent, '=')
                        ttSessionCookieJar.SessionCookie = FALSE.
            END CASE.
        END.
        
        THIS-OBJECT:HasCookies = TEMP-TABLE ttCookieJar:HAS-RECORDS.

    END METHOD.

    

END CLASS.
