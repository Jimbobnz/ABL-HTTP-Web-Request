/* uncompress.p

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

/** DO NOT USE... uncompress function does not work with GZIP compress data streams.**/

DEFINE INPUT        PARAMETER pSourceBuf    AS MEMPTR NO-UNDO.
DEFINE OUTPUT        PARAMETER pDestBuf      AS MEMPTR  NO-UNDO.
DEFINE OUTPUT       PARAMETER iretcode      AS INTEGER NO-UNDO.



PROCEDURE uncompress EXTERNAL "zlib1.dll" CDECL PERSISTENT: /* PRIVATE */
    DEFINE INPUT        PARAMETER pDestBuf    AS MEMPTR NO-UNDO.
    DEFINE INPUT-OUTPUT PARAMETER iDestSize   AS LONG NO-UNDO.
    DEFINE INPUT        PARAMETER pSourceBuf  AS MEMPTR NO-UNDO.
    DEFINE INPUT        PARAMETER iSourceSize AS LONG NO-UNDO.
    DEFINE RETURN PARAMETER iretcode AS LONG NO-UNDO.
END PROCEDURE.



DEFINE VARIABLE iDestSize     AS INTEGER NO-UNDO.
DEFINE VARIABLE iSourceSize   AS INTEGER NO-UNDO.
DEFINE VARIABLE TempBuffer    AS MEMPTR      NO-UNDO.

  iSourceSize  = GET-SIZE(pSourceBuf).
  iDestSize = (iSourceSize * 100).
  SET-SIZE(TempBuffer) = iDestSize.

RUN uncompress (TempBuffer,
                INPUT-OUTPUT iDestSize,
                pSourceBuf,
                iSourceSize,
                OUTPUT iretcode).
          
SET-SIZE(pDestBuf) = 0.
IF iretcode EQ 0 THEN
DO:
  SET-SIZE(pDestBuf) = iDestSize.
  pDestBuf = GET-BYTES(TempBuffer, 1, iDestSize).
END.

RETURN.
