USING src.url.

DEFINE VARIABLE OBJURL AS CLASS URL   NO-UNDO.

OBJURL = NEW URL('foo://username:password@example.com:8042/over/there/index.dtb?type=animal&name=narwhal#nose').

MESSAGE OBJURL:URI      SKIP
        OBJURL:UserInfo SKIP
        OBJURL:protocol SKIP
       OBJURL:hostname  SKIP
       OBJURL:port      SKIP
       OBJURL:path  SKIP
       OBJURL:filename  SKIP
       OBJURL:query     SKIP
       OBJURL:fragment      
    VIEW-AS ALERT-BOX INFO.                                                                    
