SCHEMA WMSGAL

GLOBALS
DEFINE   Applic                  RECORD LIKE usage.*,
	 CoTitle                 LIKE codib.cdes,
	 messag, ss,
	 StandardWinTitle        STRING,
	 nul, useless            RECORD
				    nulli    INTEGER,
				    nulld    DATE,
				    nullc    CHAR(1)
				 END RECORD,

	 w                       ui.Window,
	 f                       ui.Form,
	 omDomNode, AUI          om.DomNode,

	 pweb                    RECORD LIKE webuser.*,
	 CurrentSession          LIKE websess.irowid,
	 NxtAction               RECORD
				    CANCEL, EXIT,
				    REPEAT,
				    PAGORD1, PAGORD3,
				    PAGTIMO           SMALLINT
                                 END RECORD,
	 SevenCategories         ARRAY[7] OF RECORD
				    icat     INTEGER,       -- Τηρεί τους κωδ.κατηγοριών McD
				    des      CHAR(20)       -- και τα ονόματά τους
				 END RECORD,
	 WORKING_WHID            LIKE webhead.irowid,       -- ID παραγγελίας, για την οποία
							    -- έχουν ήδη διαβαστεί τα asa04[].*, isa04[].*
	 WORKING_WTIME           LIKE webhead.wh_till,

	 Racstu                  RECORD LIKE acstu.*,

         Cbprg, CBuum            ui.ComboBox

END GLOBALS




FUNCTION ThisApplic()

LET Applic.srtname = "E100"
LET Applic.program = PrgBaseName(ARG_VAL(0))
{
LET Applic.cco     = ARG_VAL(1)
}
CALL FGL_GETENV("WEBCCO") RETURNING Applic.cco

LET AUI = ui.Interface.getRootNode()
CALL StartApplicInit()
CALL DEFINES()

END FUNCTION          --  ThisApplic()





FUNCTION DEFINES()

IF NOT HasPermission("web10000") THEN EXIT PROGRAM END IF
{
CALL GetCodib("compa", Applic.cco, Applic.cco) RETURNING CoTitle
}
select cdes into CoTitle from vfcompa where ctab = "compa" and 
       ccod = 1 and ( cco = 0 OR cco = Applic.cco )
IF CoTitle IS NULL THEN
   CALL ShowMessage(4, "Application error", "Illegal password")
   EXIT PROGRAM 
END IF


OPTIONS INPUT WRAP,
        HELP FILE "gal030.iem"

--
--    Επιλογή τρεχουσας χρήσης
--

SELECT * INTO Racstu.* FROM acstu WHERE
       as_cco = Applic.cco AND as_use = YEAR(TODAY)

IF SQLCA.SQLCODE = NOTFOUND THEN 
   SELECT * INTO Racstu.* FROM acstu WHERE
	  as_cco = Applic.cco AND as_use = 
	  ( SELECT MAX(as_use) FROM acstu WHERE as_cco = Applic.cco )
   IF SQLCA.SQLCODE != 0 THEN
      CALL ShowMessage(4, "Application error", "Δεν υπάρχει ανοικτή χρήση, το πρόγραμμα σταματά.")
      EXIT PROGRAM 
   END IF
END IF

--
--    Ελεγχος δικαιώματος επιλογής της συγκεκριμένης εταιρείας
--
IF NOT HasCCOPerm(Racstu.as_cco) THEN
   CALL ShowMessage(4, "Έλεγχος δικαιωμάτων χρηστών",
		    "Δεν έχετε δικαίωμα πρόσβασης στην επιλεγμένη εταιρεία.\n")
   EXIT PROGRAM 
END IF

LET NxtAction.CANCEL =  1
LET NxtAction.EXIT   =  2
LET NxtAction.REPEAT =  3
LET NxtAction.PAGORD1=  4
LET NxtAction.PAGORD3=  5
LET NxtAction.PAGTIMO=  6

LET SevenCategories[1].icat = 502   LET SevenCategories[1].des = "Food, Frozen"
LET SevenCategories[2].icat = 504   LET SevenCategories[2].des = "Food, Refrigerated"
LET SevenCategories[3].icat = 507   LET SevenCategories[3].des = "Food, Dry"
LET SevenCategories[4].icat = 1000  LET SevenCategories[4].des = "Paper"
LET SevenCategories[5].icat = 2000  LET SevenCategories[5].des = "Operat.Supplies"
LET SevenCategories[6].icat = 3500  LET SevenCategories[6].des = "Promotional items"
LET SevenCategories[7].icat = 9500  LET SevenCategories[7].des = "Misc"

LET WORKING_WHID = NULL
LET WORKING_WTIME= NULL

END FUNCTION          --  DEFINES() 





FUNCTION HasCCOPerm(Vcco)

DEFINE   Vcco           SMALLINT,
	 perm8          CHAR(8)

LET perm8 = "cco", Vcco USING "<<&"
IF HasPerm(perm8) THEN RETURN TRUE ELSE RETURN FALSE END IF

END FUNCTION          --  HasCCOPerm(Vcco)





FUNCTION HasPerm(PermCod)

DEFINE   PermCod              LIKE perms.pe_pro,
	 ok                   SMALLINT

CALL _HasPerm(PermCod, 0) RETURNING ok
RETURN ok

END FUNCTION          --  HasPerm(PermCod)





FUNCTION HasPermission(PermCod)

DEFINE   PermCod              LIKE perms.pe_pro,
	 ok                   SMALLINT

CALL _HasPerm(PermCod, 1) RETURNING ok
RETURN ok

END FUNCTION          --  HasPermission(PermCod)





FUNCTION _HasPerm(PermCod, verbose)

DEFINE   PermCod              LIKE perms.pe_pro,
	 PermDes              LIKE prdes.pr_des,
	 similars             STRING,
	 ok, verbose          SMALLINT

CASE
   WHEN PermCod = "web10000"
		  LET PermDes = "Εκτέλεση προγράμματος E030"  
		  LET similars= NULL
   OTHERWISE
		  LET PermDes = NULL
		  LET similars= NULL
END CASE

CALL ExtraHasPerm(PermCod, PermDes, similars, verbose) RETURNING ok
RETURN ok

END FUNCTION          --  _HasPerm(PermCod, verbose)




