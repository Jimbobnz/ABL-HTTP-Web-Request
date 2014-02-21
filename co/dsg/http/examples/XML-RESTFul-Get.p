DEFINE VARIABLE objHttp             AS CLASS src.http         NO-UNDO.
DEFINE VARIABLE objHttpRequest      AS CLASS src.httpRequest  NO-UNDO.
DEFINE VARIABLE objHttpResponce     AS CLASS src.httpResponce NO-UNDO.

objHttp        = NEW src.http().
objHttpRequest = NEW src.httpRequest().

objHttpRequest:HttpMethod = 'GET'.
/* objHttpRequest:ContenTTYPE = 'application/x-www-form-urlencoded'. */

objHttpRequest:path = '/xml/203.146.212.103'.

objHttpResponce = objHttp:SynchronousRequest( 'http://freegeoip.net', objHttpRequest ). 

MESSAGE
    STRING(objHttpResponce:body)
    view-as alert-box info.

