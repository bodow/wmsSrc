--
--    WEB - Παραγγελιοληψία online για καταστήματα McDonald's
--
GLOBALS  "web109.4gl"

DEFINE   asa04, isa04,                                         -- asa04: All Items,     isa04:CurrentCategory's
         empty04           DYNAMIC ARRAY OF RECORD             -- Προϊόντα, όμοιο με το FE100.sa04.*
			      aiid  LIKE webitem.irowid,
			      awid  LIKE webtrco.irowid,
			      ast1  LIKE webitem.wi_st1,
			      ast2  LIKE webitem.wi_st2,
			      acod  LIKE webitem.wi_cod,
			      ades  LIKE items.it_des,
			      asms  LIKE webitem.wi_sms,
			      aqnt  INTEGER,
			      aprc  LIKE webitem.wi_prc,
			      anprc LIKE webitem.wi_nprc,
			      aminq LIKE webitem.wi_minq,
			      amaxq LIKE webitem.wi_maxq,
			      abpk  LIKE webitem.wi_bpk,
			      aqpro LIKE webitem.wi_qpro,
			      amsg1 LIKE webitem.wi_msg1
			   END RECORD,
         amcr, amcr_       DYNAMIC ARRAY OF RECORD             -- Για τον ορισμό του εβδομ.προγράμματος παραγγελιολ
			      dday  CHAR(12),                  -- Delivery: weekdatename που θα γίνει
			      ddat  DATE,                      -- ..        date
			      dtim  DATETIME HOUR TO MINUTE,   -- ..        time
			      dtyp  CHAR(3),                   -- Κανονική ή Μ(αρούλια) παράδοση, κλπ
			      oday  CHAR(12),                  -- Παραγγελία έως: weekdatename
			      odat  DATE,                      -- ..              date
			      otim  DATETIME HOUR TO MINUTE,   -- ..              time
			      recid INTEGER,                   -- mcrec.ID από το οποίο προκύπτει
			      whid  INTEGER                    -- webhead.ID που έχει ήδη καταχωρηθεί ή null
			   END RECORD



MAIN

DEFER INTERRUPT
CLOSE WINDOW SCREEN
IF NOT ConnectDB("WMSGAL") THEN EXIT PROGRAM END IF
CALL ThisApplic()

CALL STARTLOG("web100.log")
CALL OpenWindow("FE100")
LET w = ui.Window.getCurrent()
LET f = w.getForm()

CALL f.setElementHidden("ordhead",  TRUE)
CALL f.setElementHidden("pgorders", TRUE)
CALL f.setElementHidden("pgtimok",  TRUE)

CALL ui.Interface.setText("McDonalds's Orders-Online")


CALL MainLoop()

CALL CloseWindow()

END MAIN





FUNCTION MainLoop()

DEFINE   welcome              STRING,
	 NextAction           INTEGER,
	 mc                   RECORD LIKE mcrec.*,
	 i                    INTEGER,
	 msgString            STRING

--
--    Αναγνώριση πελάτη (login χρήστη)
--

CALL WebUserLogin() RETURNING pweb.*
IF pweb.irowid IS NULL THEN
   RETURN
ELSE
   IF pweb.wb_nowc IS NULL OR pweb.wb_nowc < pweb.wb_maxc THEN
      LET welcome = pweb.wb_nam || "\n" ||
		    pweb.wb_adr || "\n" ||
		    "ΑΦΜ: "     || pweb.wb_afm || "   ΔΟΥ: " || pweb.wb_doy
      DISPLAY welcome TO welcome
      DISPLAY BY NAME pweb.wb_lst

      IF pweb.wb_nowc IS NULL THEN LET pweb.wb_nowc = 0 END IF
      LET pweb.wb_nowc = pweb.wb_nowc + 1
      LET pweb.wb_lst  = CURRENT YEAR TO MINUTE
      UPDATE webuser SET
		     wb_nowc = pweb.wb_nowc,
		     wb_lst  = pweb.wb_lst 
	       WHERE irowid  = pweb.irowid

      INSERT INTO websess 
	   ( wb_log, wb_who, wb_sho )
	     VALUES
	   ( pweb.wb_log, pweb.wb_who, pweb.wb_sho )
      LET CurrentSession = SQLCA.SQLERRD[2]
   ELSE
      CALL Infos("Περισσότερες από " || pweb.wb_nowc || " ενεργές συνδέσεις\n" ||
		 "Παρακαλώ δοκιμάστε αργότερα")
      RETURN
   END IF
END IF

--
--    Μόλις αναγνωρίστηκε ένας νέος χρήστης (κατάστημα).  - στο global pweb.*
--    Θα συγκεντρώσουμε τα μηνύματα για αυτόν καθώς και το πρόγραμμα
--    παραγγελιοδοσίας του καταστήματος του για την επόμενη περίοδο (εβδομάδα)
--

CALL CollectMessages() RETURNING msgString
DISPLAY msgString TO allmes
call AUI.writexml("w100.xml")


MENU

   ON ACTION _orders1
		     LABEL ACTION__orders1:
		     ----------------------
		     CALL f.setElementHidden("pgmess",   TRUE)
		     CALL f.setElementHidden("ordhead",  TRUE)
		     CALL f.setElementHidden("pgtimok",  TRUE)
		     CALL f.setElementHidden("pgorders", FALSE)

		     CALL HandlePageOrders(1) RETURNING NextAction
		     CASE
			WHEN NextAction = NxtAction.EXIT
					  CALL f.setElementHidden("pgorders", TRUE)
					  LET int_flag = FALSE
					  EXIT MENU
			WHEN NextAction = NxtAction.CANCEL
					  CALL f.setElementHidden("pgorders", TRUE)
					  CALL f.setElementHidden("pgmess",   FALSE)
					  LET int_flag = FALSE
					  CONTINUE MENU
			WHEN NextAction = NxtAction.PAGORD1
					  GOTO ACTION__orders1
			WHEN NextAction = NxtAction.PAGORD3
					  GOTO ACTION__orders3
			WHEN NextAction = NxtAction.PAGTIMO
					  GOTO ACTION__timok
			OTHERWISE
					  EXIT CASE
		     END CASE

   ON ACTION _orders3
		     LABEL ACTION__orders3:
		     ----------------------
		     CALL f.setElementHidden("pgmess",   TRUE)
		     CALL f.setElementHidden("ordhead",  TRUE)
		     CALL f.setElementHidden("pgtimok",  TRUE)
		     CALL f.setElementHidden("pgorders", FALSE)

		     CALL HandlePageOrders(3) RETURNING NextAction
		     CASE
			WHEN NextAction = NxtAction.EXIT
					  CALL f.setElementHidden("pgorders", TRUE)
					  LET int_flag = FALSE
					  EXIT MENU
			WHEN NextAction = NxtAction.CANCEL
					  CALL f.setElementHidden("pgorders", TRUE)
					  CALL f.setElementHidden("pgmess",   FALSE)
					  LET int_flag = FALSE
					  CONTINUE MENU
			WHEN NextAction = NxtAction.PAGORD1
					  GOTO ACTION__orders1
			WHEN NextAction = NxtAction.PAGORD3
					  GOTO ACTION__orders3
			WHEN NextAction = NxtAction.PAGTIMO
					  GOTO ACTION__timok
			OTHERWISE
					  EXIT CASE
		     END CASE

   ON ACTION _timok
		     LABEL ACTION__timok:
		     --------------------
		     CALL f.setElementHidden("pgmess",   TRUE)
		     CALL f.setElementHidden("ordhead",  TRUE)
		     CALL f.setElementHidden("pgorders", TRUE)
		     CALL f.setElementHidden("pgtimok",  FALSE)

		     CALL HandleTimokatalogos() RETURNING NextAction
		     CASE
			WHEN NextAction = NxtAction.EXIT
					  CALL f.setElementHidden("pgtimok",  TRUE)
					  LET int_flag = FALSE
					  EXIT MENU
			WHEN NextAction = NxtAction.CANCEL
					  CALL f.setElementHidden("pgtimok",  TRUE)
					  CALL f.setElementHidden("pgmess",   FALSE)
					  LET int_flag = FALSE
					  CONTINUE MENU
			WHEN NextAction = NxtAction.PAGORD1
					  GOTO ACTION__orders1
			WHEN NextAction = NxtAction.PAGORD3
					  GOTO ACTION__orders3
			WHEN NextAction = NxtAction.PAGTIMO
					  GOTO ACTION__timok
			OTHERWISE
					  EXIT CASE
		     END CASE


   ON ACTION exit
		     --
		     --    Exit Program
		     --
		     IF YesNo("Τερματισμός του προγράμματος;") THEN 
			LET int_flag = FALSE
			EXIT MENU
		     END IF

END MENU

IF CurrentSession IS NOT NULL THEN
   UPDATE websess SET
		  wb_dte = CURRENT YEAR TO MINUTE
	    WHERE irowid = CurrentSession
   UPDATE webuser SET
		  wb_nowc = wb_nowc - 1
	    WHERE irowid  = pweb.irowid
END IF

END FUNCTION          --  MainLoop()





FUNCTION CollectMessages() 

--
--    Επ' ευκαιρίας του τρέχοντος χρήστη που μόλις έκανε login,
--    (τα στοιχεία του είναι στο pweb.*)
--    κατασκευάζουμε σε ένα μακρύ string, διάφορα μηνύματα
--    που τον αφορούν, και κυρίως το πρόγραμμα των επόμενων παραγγελιοληψιών
--

DEFINE   mc                   RECORD LIKE mcrec.*,
	 cal                  RECORD
				 calday   INTEGER,
				 nowtim   DATETIME HOUR TO MINUTE,
				 orplus   INTEGER
			      END RECORD,
	 mmm                  RECORD LIKE webmess.*,
	 i                    INTEGER,
	 msgString            STRING


LET msgString = NULL

--
--    1. Προσωπικά μηνύματα
--
IF pweb.wb_fl1 IS NOT NULL THEN
   IF msgString IS NULL THEN
      LET msgString = pweb.wb_fl1
   ELSE
      LET msgString = msgString.trimRight() || "\n" || pweb.wb_fl1
   END IF
END IF
IF pweb.wb_fl2 IS NOT NULL THEN
   IF msgString IS NULL THEN
      LET msgString = pweb.wb_fl2
   ELSE
      LET msgString = msgString.trimRight() || "\n" || pweb.wb_fl2
   END IF
END IF
IF pweb.wb_fl3 IS NOT NULL THEN
   IF msgString IS NULL THEN
      LET msgString = pweb.wb_fl3
   ELSE
      LET msgString = msgString.trimRight() || "\n" || pweb.wb_fl3
   END IF
END IF
IF msgString IS NULL THEN
   LET msgString = " \n"
ELSE
   LET msgString = msgString.trimRight() || " \n" 
END IF

--
--    2. Γενικά μηνύματα μηνός - προς όλους
--
SELECT * INTO mmm.* FROM webmess WHERE 
       wm_use = YEAR(TODAY) AND wm_umn = MONTH(TODAY) 
IF SQLCA.SQLCODE != NOTFOUND THEN 
   IF mmm.wb_lin1 IS NOT NULL THEN
      LET msgString = msgString.trimRight() || "\n" || mmm.wb_lin1
   END IF
   IF mmm.wb_lin2 IS NOT NULL THEN
      LET msgString = msgString.trimRight() || "\n" || mmm.wb_lin2
   END IF
   IF mmm.wb_lin3 IS NOT NULL THEN
      LET msgString = msgString.trimRight() || "\n" || mmm.wb_lin3
   END IF
   IF mmm.wb_lin4 IS NOT NULL THEN
      LET msgString = msgString.trimRight() || "\n" || mmm.wb_lin4
   END IF
   IF mmm.wb_lin5 IS NOT NULL THEN
      LET msgString = msgString.trimRight() || "\n" || mmm.wb_lin5
   END IF
   IF mmm.wb_lin6 IS NOT NULL THEN
      LET msgString = msgString.trimRight() || "\n" || mmm.wb_lin6
   END IF
   IF mmm.wb_lin7 IS NOT NULL THEN
      LET msgString = msgString.trimRight() || "\n" || mmm.wb_lin7
   END IF
   IF mmm.wb_lin8 IS NOT NULL THEN
      LET msgString = msgString.trimRight() || "\n" || mmm.wb_lin8
   END IF
   IF mmm.wb_lin9 IS NOT NULL THEN
      LET msgString = msgString.trimRight() || "\n" || mmm.wb_lin9
   END IF
   IF mmm.wb_lin10 IS NOT NULL THEN
      LET msgString = msgString.trimRight() || "\n" || mmm.wb_lin10
   END IF
END IF


--
--    Συγκέντρωση των επικείμενων παραγγελιών του
--
CALL Date2Calendar(TODAY) RETURNING useless.nulli, useless.nulli, cal.calday
DECLARE c_mymcrec CURSOR FOR
   SELECT * FROM mcrec WHERE
	  mc_ekk = pweb.wb_i1 AND mc_act = 1

CALL amcr.Clear()
LET i = 0
FOREACH c_mymcrec INTO mc.*
   IF mc.mc_dyb = cal.calday THEN
      LET cal.nowtim = CURRENT HOUR TO MINUTE
      IF cal.nowtim < mc.mc_tim THEN
	 LET cal.orplus = 0
      ELSE
	 LET cal.orplus = 7
      END IF
   ELSE
      LET cal.orplus = ( mc.mc_dyb + 7 - cal.calday ) MOD 7 
   END IF
   LET i = i+1
   LET amcr[i].odat = TODAY + cal.orplus
   LET amcr[i].otim = mc.mc_tim
   LET amcr[i].recid= mc.irowid
   LET amcr[i].whid = NULL
   CASE
      WHEN mc.mc_typ != "Κ"         LET amcr[i].dtyp = mc.mc_typ
      OTHERWISE                     LET amcr[i].dtyp = NULL
   END CASE
   LET amcr[i].ddat = amcr[i].odat + mc.mc_dysb
   LET amcr[i].dtim = mc.mc_dlvt
   CALL DateName(amcr[i].ddat) RETURNING amcr[i].dday
   CALL DateName(amcr[i].odat) RETURNING amcr[i].oday

   SELECT MAX(irowid) INTO amcr[i].whid FROM webhead WHERE 
	  wh_orh = 0 AND 
	  wh_who = pweb.wb_who AND wh_sho = pweb.wb_sho AND
	  wh_i1 = amcr[i].recid AND
	  wh_due = amcr[i].ddat
   IF SQLCA.SQLCODE = NOTFOUND THEN LET amcr[i].whid = NULL END IF

END FOREACH

--
--    Sort array 
--
CALL amcr_Sort()
--

LET msgString = msgString.trimRight() || 
		"\n\n\nΕΠΙΚΕΙΜΕΝΕΣ ΠΑΡΑΔΟΣΕΙΣ\n--------------------------------" 

FOR i = 1 TO amcr.getLength()
   IF amcr[i].dtyp IS NOT NULL THEN
      LET msgString = msgString.trimRight() || "\n" ||
		      "Παράδοση  " || "(" || amcr[i].dtyp CLIPPED || ") :"
   ELSE
      LET msgString = msgString.trimRight() || "\n" ||
		      "Παράδοση  " || "      :"
   END IF
   LET msgString = msgString.trimRight() || 
		   amcr[i].dday CLIPPED || " " || amcr[i].ddat   || " " || amcr[i].dtim ||
		   "   Παραγγελία έως: " || amcr[i].oday CLIPPED || " " ||
		   amcr[i].odat || " " || amcr[i].otim
   IF amcr[i].whid IS NOT NULL THEN
      LET msgString = msgString.trimRight() || " - Σε εξέλιξη"
   END IF
END FOR
RETURN msgString

END FUNCTION          --  CollectMessages() 





FUNCTION amcr_Sort()
--
--    Σορτάρει το amcr[].*, με βάση καρφωτή λογική comparer() και με χρήση του
--    ομοίου array amcr_
--    "Επιστρέφει" το amcr[].* ταξινομημένο.
--

DEFINE   i, j, satisfied         INTEGER

CALL amcr_.Clear()
FOR i = 1 TO amcr.getLength()
   LET satisfied = FALSE
   FOR j = 1 TO amcr_.getLength()
      IF amcr[i].odat < amcr_[j].odat OR
         amcr[i].odat = amcr_[j].odat AND amcr[i].otim < amcr_[j].otim THEN
	 --
	 --   Το source[i] είναι μικρότερο του target[j]
	 --
	 CALL amcr_.insertElement(j)
	 LET amcr_[j].* = amcr[i].*
	 LET satisfied = TRUE
	 EXIT FOR
      END IF
   END FOR
   IF NOT satisfied THEN
      CALL amcr_.appendElement()
      LET amcr_[amcr_.getLength()].* = amcr[i].*
   END IF
END FOR
CALL amcr.Clear()
FOR j = 1 TO amcr_.getLength()
   LET amcr[j].* = amcr_[j].*
END FOR

END FUNCTION          --  amcr_Sort()






FUNCTION WebUserLogin() 

DEFINE   DataSource           CHAR(16),
         username, password   CHAR(16),
	 DBrc, ok, tries      SMALLINT,
         lpweb                RECORD LIKE webuser.*,
	 loc                  RECORD
				 username, password   CHAR(16)
			      END RECORD


CALL OpenWindow("FLIB04")
CALL ui.Interface.setImage("webapp")
LET loc.username = NULL
LET loc.password = NULL
LET ok           = FALSE
LET tries        = 0
LET DataSource   = "webuser"
DISPLAY DataSource TO msg

INPUT BY NAME loc.* WITHOUT DEFAULTS
      ATTRIBUTE ( UNBUFFERED)

   AFTER INPUT
      IF int_flag THEN EXIT INPUT END IF
      IF loc.username IS NULL THEN NEXT FIELD username END IF
      IF loc.password IS NULL THEN NEXT FIELD password END IF
      --
      --    Try to connect ..
      --
      LET tries = tries+1
      WHENEVER ERROR CONTINUE 
      SELECT * INTO lpweb.* FROM webuser WHERE 
             wb_log = loc.username AND wb_psw = loc.password AND
	     wb_act = 1
      LET DBrc = SQLCA.SQLCODE
      WHENEVER ERROR STOP 

      IF DBrc != 0 THEN
	 --
	 --    DISPLAY 
	 --
         INITIALIZE lpweb.* TO NULL
	 LET ss = "Ανεπιτυχής σύνδεση. Σφάλμα:" ||  DBrc
	 DISPLAY ss TO err
	 IF tries <= 2 THEN NEXT FIELD username END IF
      END IF

END INPUT
CALL CloseWindow()
IF int_flag THEN
   LET int_flag = FALSE
   INITIALIZE lpweb.* TO NULL
END IF
RETURN lpweb.*

END FUNCTION          --  WebUserLogin() 





FUNCTION HandlePageOrders(Vstu)

--
--    Κληθήκαμε για να κάνουμε προβολή/διαχείριση παραγγελιών webhead που
--    βρίσκονται σε κατάσταση ανάλογα με το Vstu:
--    Vstu=1:    Διαχείριση webhead "προσωρινών" δηλ. wh_orh = 0
--    Vstu=3:    Διαχείριση webhead "οριστικών " δηλ. wh_orh > 0
--    Οριστική είναι μια παραγγελία όταν έχει μεταφερθεί στα orhdr/ortrn
--    Από εκεί μπορεί ήδη να έχει ολοκληρωθεί(ΤΔΑ) ή να είναι σε εξέλιξη.
--
--    Στην οθόνη έχουμε hidden όλες τις άλλες σελίδες πλην της pgorders σελίδας.
--    Δεν χρειαζόμαστε globals πέραν του pweb.* ( = αποθέτης/χρήστης )
--
--    Τις προσωρινές τις δείχνει όλες
--    Τις οριστικές δείχνει με βάση το due date στο διάστημα [ TODAY-31, TODAY+5 ]
--
--    Τέλος, δείχνει ενεργά ή μή ενεργά τα κουμπιά διαχείρισης webhead, ανάλογα
--    με το κατά πόσον έχουμε γραμμές παραγγελιών να προβάλουμε ή κενό array
--

DEFINE   Vstu                 SMALLINT,                              -- 1 or 3
         MODE_Proswrines      SMALLINT,
         asa02                DYNAMIC ARRAY OF RECORD LIKE webhead.*,
         pwh                  RECORD LIKE webhead.*,
	 {
         customers            DYNAMIC ARRAY OF RECORD             -- Χρήσιμο στο View Οριστικών
                                 wh_dwho  LIKE webhead.wh_dwho    -- Τηρεί τον κατάλογο των πελατών οι οποίοι
			      END RECORD,                         -- κινήθηκαν στο υπερδιάστημα προβολής
         criteria             RECORD
                                 dwho     LIKE webhead.wh_dwho, 
				 due      DATE
			      END RECORD,   
	 customersIsEmpty     SMALLINT,
	 }
	 maxohstu             LIKE orhdr.oh_stu,
	 ssq, ss              STRING,
	 dt1, dt2             DATE,
	 inewhead, updated,
	 i, j, fnd,
	 NextAction           INTEGER


CASE
   WHEN Vstu = 1        LET MODE_Proswrines = TRUE
   OTHERWISE            LET MODE_Proswrines = FALSE
END CASE

CASE
   WHEN MODE_Proswrines
	    LET ssq = "SELECT * FROM webhead WHERE "                     ||
                            " wh_orh = 0 AND wh_who = ? AND wh_sho = ? " ||
		      " ORDER BY wh_orh, wh_who, wh_sho, irowid "
   WHEN NOT MODE_Proswrines
	    LET ssq = "SELECT wh.*, n.na_nam "        ||
                       " FROM webhead wh, names n "   ||
                      " WHERE wh.wh_who = ? AND wh.wh_sho = ? AND wh.wh_due <= ? AND wh.wh_due >= ? AND " ||
	                    " wh_orh > 0 AND n.na_key = wh.wh_dwho AND wh.wh_stu >= 1 " ||
		      " ORDER BY wh.wh_who, wh.wh_sho, wh.wh_due DESC"
END CASE

PREPARE pords FROM ssq
DECLARE c_ords1 CURSOR FOR pords



LABEL STARTAGAIN:
-----------------

LET NextAction = NxtAction.CANCEL

LET i = 0
CALL asa02.Clear()

CASE
   WHEN MODE_Proswrines    OPEN c_ords1 USING pweb.wb_who, pweb.wb_sho
   OTHERWISE               LET dt1 = TODAY + 500
		           LET dt2 = TODAY - 31
		           OPEN c_ords1 USING pweb.wb_who, pweb.wb_sho, dt1, dt2
END CASE

FOREACH c_ords1 INTO pwh.*
   LET i = i+1
   LET asa02[i].* = pwh.*
   --
   --    Στην περίπτωση των οριστικοποιημένων παραγγελιών,
   --    επιθυμούμε να δείχνουμε στο χρήστη κάποια "status πληροφορία"
   --    Χρησιμοποιούμε προς αυτό, το πεδίο webhead.wh_fl2 που κατά τα λοιπά είναι ΔΧ-πεδίο
   --
   IF NOT MODE_Proswrines THEN
      SELECT irowid FROM orhdr WHERE irowid = pwh.wh_orh
      IF SQLCA.SQLCODE = NOTFOUND THEN 
	 --
	 --    ΔΕΝ βρέθηκε, η μάνα παραγγελία: Πιθανώς έχει μετασχηματιστεί
	 --
	 SELECT MAX(oh_stu) INTO maxohstu FROM orhdr WHERE oh_mch = pwh.wh_orh
	 CASE
	    WHEN maxohstu[1] = "0"     LET asa02[i].wh_fl2 = "Σε εξέλιξη"
	    WHEN maxohstu[1] = "9"     LET asa02[i].wh_fl2 = "Τιμολογημένη"
	    WHEN maxohstu[1] = "C"     LET asa02[i].wh_fl2 = "Ακυρωμένη"
	    OTHERWISE                  LET asa02[i].wh_fl2 = "??"
	 END CASE
      ELSE
	 --
	 --    Βρέθηκε, η μάνα παραγγελία: ΔΕΝ έχει μετασχηματιστεί ακόμα
	 --
	 LET asa02[i].wh_fl2 = "Σε αναμονή"
      END IF
   END IF

END FOREACH



--
--    Decoration της σελίδας
--
IF MODE_Proswrines THEN

   CALL ChangeElementsAtt("Page", "02", "text",  "Παραγγελίες")
   CALL ChangeElementsAtt("Page", "02", "image", "icoorder")
   CALL ChangeElementsAtt("Page", "021","text",  "Προσωρινές")

   CALL ShowHideColumn("formonly.datupd")
   CALL ShowHideColumn("formonly.wh_till")
   CALL HideFormColumn("formonly.wh_fl2")
   CALL HideFormColumn("formonly.wh_sent")

ELSE

   CALL ChangeElementsAtt("Page", "02", "text",  "Παραδόσεις")
   CALL ChangeElementsAtt("Page", "02", "image", "icosent")
   CALL ChangeElementsAtt("Page", "021","text",  "Οριστικές")

   CALL ShowHideColumn("formonly.wh_sent")
   CALL ShowHideColumn("formonly.wh_fl2")
   CALL HideFormColumn("formonly.wh_till")
   CALL HideFormColumn("formonly.datupd")

END IF
--


--
--    Είμαστε στην σελίδα προβολής των ( προσωρινών ή οριστικών ) παραγγελιών
--    Εχουμε γεμίσει το array asa02[].* με τα header και τα δείχνουμε
--
DISPLAY ARRAY asa02 TO sa02.*
        ATTRIBUTE ( UNBUFFERED, ACCEPT=FALSE )

   BEFORE DISPLAY
      IF MODE_Proswrines THEN
	 CALL DIALOG.setActionActive("_orders1", 0)
	 CALL DIALOG.setActionActive("_orders3", 1)
	 CALL DIALOG.setActionActive("btn1new", 1)
	 IF asa02.getLength() > 0 THEN
	    CALL DIALOG.setActionActive("btn1upd", 1)
	    CALL DIALOG.setActionActive("btn1del", 1)
	    CALL DIALOG.setActionActive("btn1ok",  1)
	 END IF
	 CALL DIALOG.setActionActive("btn1prt", 0)
      ELSE
	 CALL DIALOG.setActionActive("_orders1", 1)
	 CALL DIALOG.setActionActive("_orders3", 0)
	 CALL DIALOG.setActionActive("btn1new", 0)
	 CALL DIALOG.setActionActive("btn1upd", 0)
	 CALL DIALOG.setActionActive("btn1del", 0)
	 CALL DIALOG.setActionActive("btn1ok",  0)
	 CALL DIALOG.setActionActive("btn1prt", 1)
      END IF


   {
   ON ACTION email
      LET i = ARR_CURR()
      CALL EmailDC(asa02[i].irowid)
   }


   ON ACTION btn1New
      --
      --    Καταχώρηση νέας προσωρινής παραγγελίας
      --
      IF MODE_Proswrines THEN
	 CALL cEDITwebhead(0) RETURNING inewhead, updated   -- >0 if a new webhead/trco inserted
							    --  0 if user cancels
	 IF inewhead > 0 THEN
	    LET NextAction = NxtAction.REPEAT 
	    EXIT DISPLAY
	 END IF
      END IF

   ON ACTION btn1Upd
      IF MODE_Proswrines THEN
	 LET i = ARR_CURR()
	 IF i IS NOT NULL AND i > 0 AND asa02.getLength() >= i THEN
	    IF asa02[i].irowid IS NOT NULL THEN
	       CALL cEDITwebhead(asa02[i].irowid) RETURNING useless.nulli, updated
	       IF updated THEN
		  --
		  --    asa02[i].* needs update
		  --
		  SELECT * INTO asa02[i].* FROM webhead WHERE irowid = asa02[i].irowid
	       END IF
	    END IF
	 END IF
      END IF

   ON ACTION btn1Del
      IF MODE_Proswrines THEN
	 LET i = ARR_CURR()
	 IF i IS NOT NULL AND i > 0 AND asa02.getLength() >= i THEN
	    IF asa02[i].irowid IS NOT NULL AND asa02[i].wh_orh = 0 THEN
               IF InTimeUpdates(asa02[i].wh_till, 1) THEN
		  IF YesNo("Διαγραφή της παραγγελίας με αριθμό " || asa02[i].wh_cord) THEN
		     DELETE FROM webtrco WHERE wc_head = asa02[i].irowid
		     DELETE FROM webhead WHERE irowid  = asa02[i].irowid
		     LET NextAction = NxtAction.REPEAT 
		     EXIT DISPLAY
		  END IF
	       END IF
	    END IF
	 END IF
      END IF
      
   ON ACTION btn1Ok
      IF MODE_Proswrines THEN
	 LET i = ARR_CURR()
	 IF i IS NOT NULL AND i > 0 AND asa02.getLength() >= i THEN
	    IF asa02[i].irowid IS NOT NULL THEN
	       SELECT SUM(wc_qnt) INTO useless.nulli FROM webtrco WHERE wc_head = asa02[i].irowid
	       IF useless.nulli IS NULL OR useless.nulli = 0 THEN
		  CALL Infos("Η παραγγελία αυτή δεν περιέχει ποσότητες\n" ||
			     "Η οριστικοποίηση δεν μπορεί να γίνει")
		  CONTINUE DISPLAY
	       END IF
	       IF YesNo("Παραγγελία " || asa02[i].wh_cord      || 
			" για "       || asa02[i].wh_due || "\n\n" ||
			"Να οριστικοποιηθεί;") THEN
		  CALL Confirm_webhead(asa02[i].irowid) RETURNING updated
		  IF updated THEN
		     LET NextAction = NxtAction.REPEAT 
		     EXIT DISPLAY
		  END IF
	       END IF
	    END IF
	 END IF
      END IF

   ON ACTION btn1Prt
      IF NOT MODE_Proswrines THEN
	 LET i = ARR_CURR()
	 IF i IS NOT NULL AND i > 0 AND asa02.getLength() >= i THEN
	    IF asa02[i].irowid IS NOT NULL THEN
	       CALL PrintOrder(asa02[i].irowid)
	    END IF
	 END IF
      END IF


   ON ACTION _orders1
      CALL ClearPagetrco()
      LET NextAction = NxtAction.PAGORD1
      EXIT DISPLAY 

   ON ACTION _orders3
      CALL ClearPagetrco()
      LET NextAction = NxtAction.PAGORD3
      EXIT DISPLAY 

   ON ACTION _timok
      CALL ClearPagetrco()
      LET NextAction = NxtAction.PAGTIMO
      EXIT DISPLAY 


   ON ACTION _PageOrdtrco
      --
      --    Επιλογή δεύτερης σελίδας: αυτής που δείχνει την ανάλυση των details webtrco
      --
      --    Αν είσαι πάνω σε συμπληρωμένη γραμμή παραγγελίας,
      --    δείξε τα αντίστοιχα προϊόντα
      --    Λάβε υπόψη δε το MODE Προσωρινών/Οριστικών εν ισχύ.
      --
      LET i = ARR_CURR()
      IF i > 0 AND asa02.getLength() >= i THEN
	 IF asa02[i].irowid IS NOT NULL THEN
	    CALL LoadAllWebItems(asa02[i].irowid)
	    CALL InTrcod(asa02[i].irowid, MODE_Proswrines, TRUE)
	 END IF
      END IF


   ON ACTION exit
      --
      --    Exit Program
      --
      LET int_flag = FALSE
      IF YesNo("Τερματισμός του προγράμματος;") THEN 
	 LET NextAction = NxtAction.EXIT
	 EXIT DISPLAY 
      END IF

END DISPLAY

IF NextAction = NxtAction.REPEAT THEN
   GOTO STARTAGAIN
END IF

RETURN NextAction 

END FUNCTION          --  HandlePageOrders(Vstu)





FUNCTION HandleTimokatalogos()

DEFINE   NextAction           INTEGER,
	 imonth, i, j         INTEGER,
	 ButtonShow           SMALLINT,
	 ss                   STRING,
	 loc                  RECORD
				 uum      INTEGER,
				 use, umn INTEGER
			      END RECORD,
	 asa03, isa03         DYNAMIC ARRAY OF RECORD
				 id    LIKE webitem.irowid,
				 tcod  LIKE webitem.wi_cod,
				 tsms  LIKE webitem.wi_sms,
				 tdes  CHAR(40),
				 tprc  LIKE webitem.wi_prc,
				 tnprc LIKE webitem.wi_nprc,
				 tst2  LIKE webitem.wi_st2
			      END RECORD,
	 pp                   RECORD
                                 irowid   LIKE webitem.irowid,
				 wi_cod   LIKE webitem.wi_cod, 
				 wi_sms   LIKE webitem.wi_sms, 
				 it_des   LIKE items.it_des,
				 wi_prc   LIKE webitem.wi_prc, 
				 wi_nprc  LIKE webitem.wi_nprc, 
				 wi_st2   LIKE webitem.wi_st2
			      END RECORD


--
--    Δύο πιθανοί μήνες για προβολή: Ο τρέχον και ο επόμενος
--    Φόρτωσε τους σε combo για να επιλέξει ο χρήστης
--
LET Cbuum = ui.ComboBox.forName("formonly.uum")
IF Cbuum IS NULL THEN
   CALL ShowMessage(4, "Internal fatal error",
		    "formonly.uum cb not found")
   RETURN NxtAction.PAGORD1
END IF
CALL Cbuum.Clear()

LET imonth = 100 * YEAR(TODAY) + MONTH(TODAY)
LET ss = "Μήνας: " || MONTH(TODAY) || "/" || YEAR(TODAY)
CALL Cbuum.addItem(imonth, ss.trimRight())
LET loc.uum = imonth

IF MONTH(TODAY) < 12 THEN
   LET imonth = imonth + 1
   LET ss = "Μήνας: " || MONTH(TODAY)+1 || "/" || YEAR(TODAY)
ELSE
   LET imonth = 100 * (YEAR(TODAY)+1) + 1
   LET ss = "Μήνας: 1/" || YEAR(TODAY)+1
END IF
CALL Cbuum.addItem(imonth, ss.trimRight())



LABEL INPUTMONTH:
-----------------


LET ButtonShow = 1
INPUT BY NAME loc.uum WITHOUT DEFAULTS
      ATTRIBUTE ( UNBUFFERED )

   ON ACTION _orders1
      LET NextAction = NxtAction.PAGORD1
      LET loc.uum = NULL                  -- ΣΗΜΑΙΝΕΙ: ΜΗΝ προχωράς παρακάτω
      EXIT INPUT

   ON ACTION _orders3
      LET NextAction = NxtAction.PAGORD3
      LET loc.uum = NULL                  -- ΣΗΜΑΙΝΕΙ: ΜΗΝ προχωράς παρακάτω
      EXIT INPUT

   ON ACTION btn3All
      LET ButtonShow = 1
      EXIT INPUT

   ON ACTION btn3New
      LET ButtonShow = 2
      EXIT INPUT

   ON ACTION exit
      --
      --    Exit Program
      --
      LET int_flag = FALSE
      IF YesNo("Τερματισμός του προγράμματος;") THEN 
	 LET loc.uum = NULL
	 LET NextAction = NxtAction.EXIT
	 EXIT INPUT
      END IF

   AFTER INPUT
      IF int_flag THEN 
	 LET loc.uum = NULL
	 LET NextAction = NxtAction.CANCEL
	 EXIT INPUT 
      END IF

END INPUT

IF loc.uum IS NOT NULL AND NOT int_flag THEN
   LET loc.umn = loc.uum MOD 100
   LET loc.use = (loc.uum - loc.umn) / 100
ELSE
   LET int_flag = FALSE
   GOTO FUNCENDS
END IF

--
--    Φόρτωμα του πλήρους τιμοκαταλόγου για το κατάστημα
--
DECLARE c_wis CURSOR FOR
   SELECT w.irowid, w.wi_cod, w.wi_sms, i.it_des, w.wi_prc, w.wi_nprc, w.wi_st2
     FROM webitem w, items i
    WHERE w.wi_who = pweb.wb_who AND
	  w.wi_sho = pweb.wb_sho AND
	  w.wi_use = loc.use AND
	  w.wi_umn = loc.umn AND
	  w.wi_cco = Racstu.as_cco AND
	  w.wi_avail > 0 AND
	  i.it_cod = w.wi_cod

CALL asa03.Clear()
LET i = 0
FOREACH c_wis INTO pp.*
   LET i = i+1
   LET asa03[i].id    = pp.irowid
   LET asa03[i].tcod  = pp.wi_cod
   LET asa03[i].tsms  = pp.wi_sms
   LET asa03[i].tdes  = pp.it_des
   LET asa03[i].tprc  = pp.wi_prc
   LET asa03[i].tnprc = pp.wi_nprc
   LET asa03[i].tst2  = pp.wi_st2
END FOREACH


LABEL REFRESHITEMS:
-------------------

CASE
   WHEN ButtonShow = 1     -- Δείξε ΟΛΑ τα είδη
			   CALL isa03.Clear()
			   FOR i = 1 TO asa03.getLength()
			      LET isa03[i].* = asa03[i].*
			   END FOR
   WHEN ButtonShow = 2     -- Δείξε τα είδη με ΝΕΕΣ τιμές only
			   CALL isa03.Clear()
			   LET j = 0
			   FOR i = 1 TO asa03.getLength()
			      IF asa03[i].tnprc > 0 THEN
				 LET j = j+1
				 LET isa03[j].* = asa03[i].*
			      END IF
			   END FOR
			   IF isa03.getLength() = 0 THEN
			      CALL Infos("Δεν υπάρχουν αλλαγές στον τιμοκατάλογο\n" ||
					 "Βλέπετε τις τιμές όλων των ειδών")
			      LET Buttonshow = 1
			      GOTO REFRESHITEMS
			   END IF
END CASE

LET NextAction = NxtAction.CANCEL
DISPLAY ARRAY isa03 TO sa03.*
        ATTRIBUTE ( UNBUFFERED, ACCEPT=FALSE )

   ON ACTION btn3All
      LET ButtonShow = 1
      LET NextAction = NxtAction.REPEAT
      EXIT DISPLAY

   ON ACTION btn3New
      LET ButtonShow = 2
      LET NextAction = NxtAction.REPEAT
      EXIT DISPLAY

   ON ACTION _orders1
	 LET NextAction = NxtAction.PAGORD1
	 EXIT DISPLAY

   ON ACTION _orders3
	 LET NextAction = NxtAction.PAGORD3
	 EXIT DISPLAY

   ON ACTION btn3Prt
         CALL ReportTimok(loc.use, loc.umn, ButtonShow)

   ON ACTION exit
	 --
	 --    Exit Program
	 --
	 LET int_flag = FALSE
	 IF YesNo("Τερματισμός του προγράμματος;") THEN 
	    LET NextAction = NxtAction.EXIT
	    EXIT DISPLAY
	 END IF

   ON ACTION cancel
	 LET NextAction = NxtAction.CANCEL
	 EXIT DISPLAY

END DISPLAY
LET int_flag = FALSE

CASE
   WHEN NextAction = NxtAction.REPEAT     GOTO REFRESHITEMS
   WHEN NextAction = NxtAction.CANCEL     GOTO INPUTMONTH
   OTHERWISE                              EXIT CASE
END CASE


LABEL FUNCENDS:
---------------

--
--    Clear rows
--
CALL isa03.Clear()
DISPLAY ARRAY isa03 TO sa03.*
   BEFORE DISPLAY
      EXIT DISPLAY
END DISPLAY

RETURN NextAction 

END FUNCTION          --  HandleTimokatalogos()





FUNCTION FormatAddress(Vwho, Vsho) 

DEFINE   Vwho                 LIKE webhead.wh_dwho,
         Vsho                 LIKE webhead.wh_dsho,
         sho                  RECORD
				 sh_adr   LIKE shops.sh_adr,
				 sh_cit   LIKE shops.sh_cit
			      END RECORD,
	 retadr               CHAR(60)

SELECT sh_adr, sh_cit INTO sho.* FROM shops WHERE 
       sh_acc = 30 AND sh_acci = Vwho AND sh_sho = Vsho
IF SQLCA.SQLCODE = NOTFOUND THEN INITIALIZE sho.* TO NULL END IF
CASE
   WHEN sho.sh_adr IS NOT NULL AND sho.sh_cit IS NOT NULL 
		  LET retadr = sho.sh_adr CLIPPED, " ", sho.sh_cit CLIPPED
   WHEN sho.sh_adr IS NOT NULL AND sho.sh_cit IS     NULL 
		  LET retadr = sho.sh_adr CLIPPED
   WHEN sho.sh_adr IS     NULL AND sho.sh_cit IS NOT NULL 
		  LET retadr = sho.sh_cit CLIPPED
   OTHERWISE
		  LET retadr = NULL
END CASE
RETURN retadr

END FUNCTION          --  FormatAddress(Vwho, Vsho) 




FUNCTION cEDITwebhead(wheadID)
--
--    Ο χρήστης μόλις πάτησε κουμπί για "Προσθήκη νέας προσωρινής παραγγελίας" ή "Μεταβολή"
--    Βασιζόμαστε στο global "ταυτότητας" του χρήστη(αποθέτη): pweb.*
--    αλλά και στο ήδη κατασκευασμένο πρόγραμμα αναμενόμενων παραγγελιοληψιών amcr[].*
--
--    Ανάλογα την τιμή wheadID αν είναι 0 ή >0 καταλαβαίνουμε αν πρόκειται για Add/Update και 
--    πράτουμε ανάλογα
--    Ξεκινάμε να δεχτούμε webhead/webtrco input data για καταχώρηση
--    Επιστρέφει το ID της νέας παραγγελίας που εισάγεται ή 0 και ένδειξη ότι έγιναν ενημερώσεις
--

DEFINE   wheadID                 LIKE webhead.irowid,
         inewhead, updated       INTEGER

--
--    Έχουμε χρονικό περιθώριο ενημέρωσης;
--
IF wheadID > 0 THEN
   LET updated = FALSE
   IF NOT InTimeUpdatesID(wheadID, 1) THEN RETURN wheadID, updated END IF
END IF
--
CALL f.setElementHidden("ordhead",   FALSE)
CALL f.setElementHidden("ordoper",   TRUE)   
CALL f.setElementHidden("pgordhead", TRUE)
CALL ChangeElementsAtt("Button", "b06", "text", " Νέο Είδος")
CALL ui.Interface.Refresh()

CALL EDITwebhead(wheadID) RETURNING inewhead, updated
IF inewhead > 0 THEN
   CALL LoadAllWebItems(inewhead)
   CALL InTrcod(inewhead, TRUE, TRUE)
END IF


CALL f.setElementHidden("pgordhead", FALSE)
CALL f.setElementHidden("ordoper",   FALSE)   
CALL f.setElementHidden("ordhead",   TRUE)
CALL ChangeElementsAtt("Button", "b06", "text", " Νέα Παραγγελία")
CALL ui.Interface.Refresh()
RETURN inewhead, updated

END FUNCTION          --  cEDITwebhead(wheadID)





FUNCTION EDITwebhead(wheadID)
--
--    Edit webhead.*
--    wheadID=0:  Add a new record
--    wheadID>0:  Edit the record webhead.irowid = wheadID
--    Globals: Racstu.* && pweb.* && amcr[].*
--

DEFINE   wheadID              LIKE webhead.irowid,
	 pp                   RECORD LIKE webhead.*,
	 ss                   STRING,
	 char16               CHAR(16),
	 i, k, combocode      INTEGER,
	 DBrc, updated        INTEGER,
	 loc                  RECORD 
                                 program  INTEGER
			      END RECORD

LET updated = FALSE

--
--    Βρες το combo προγραμματισμένων αναμενόμενων παραγγελιών
--
LET Cbprg = ui.ComboBox.forName("formonly.program")

IF Cbprg IS NULL THEN
   CALL ShowMessage(4, "Internal fatal error",
		    "formonly.program cb not found")
   RETURN wheadID, updated
END IF

CALL Cbprg.Clear()
LET loc.program = NULL

FOR i = 1 TO amcr.getLength()
   LET combocode = i
   LET ss = amcr[i].dday || " "   ||
            amcr[i].ddat || " - " ||
            amcr[i].dtim 
   IF amcr[i].dtyp IS NOT NULL THEN
      LET ss = ss.trimRight() || "  (" || amcr[i].dtyp clipped || ")"
   END IF
   --
   --   Εάν έχει ήδη καταχωρηθεί η αντίστοιχη παραγγελία, τότε "σημάδεψε" αυτή την επιλογή
   --   Ο κωδικός επιλογής γίνεται > 10000
   --   και αυτό ελέγχεται σε πολλά σημεία παρακάτω ωε τέτοια συνθήκη (program > 10000)
   --
   SELECT irowid FROM webhead WHERE
	  wh_due = amcr[i].ddat AND wh_i1 = amcr[i].recid
   IF SQLCA.SQLCODE != NOTFOUND THEN 
      LET combocode = 10000+i
      LET ss = ss.trimRight() || "  (Καταχωρημένη)"
   END IF
   CALL Cbprg.addItem(combocode, ss.trimRight())
   IF loc.program IS NULL AND combocode < 10000 THEN
      LET loc.program = combocode
   END IF
END FOR
LET i = amcr.getLength()+1
LET ss = "Extra παραγγελία - εκτός προγράμματος"
CALL Cbprg.addItem(i, ss.trimRight())
IF loc.program IS NULL THEN
   LET loc.program = i
END IF


IF wheadID = 0 THEN
   INITIALIZE pp.* TO NULL
   LET pp.wh_log = pweb.wb_log
   LET pp.wh_who = pweb.wb_who
   LET pp.wh_sho = pweb.wb_sho
   LET pp.wh_cco = Racstu.as_cco
   LET pp.wh_dwho= pweb.wb_who
   LET pp.wh_dsho= pweb.wb_sho
   LET pp.wh_dat = TODAY
   LET pp.wh_stu = 1
   LET pp.wh_orh = 0
ELSE
   SELECT * INTO pp.* FROM webhead WHERE irowid = wheadID
END IF

INPUT BY NAME loc.program, pp.wh_due, pp.wh_cord, pp.wh_till, pp.wh_ent, pp.wh_obs
      WITHOUT DEFAULTS
      -- FROM sr02.*
      ATTRIBUTE ( UNBUFFERED )

   BEFORE INPUT
      IF loc.program IS NOT NULL AND loc.program > 0 AND loc.program <= amcr.getLength() THEN
	 LET k = loc.program MOD 10000
	 LET pp.wh_due = amcr[k].ddat
	 LET char16 = amcr[k].odat using "yyyy-mm-dd", " ", 
		      amcr[k].otim
	 LET pp.wh_till = char16
      ELSE
	 INITIALIZE pp.wh_due, pp.wh_till TO NULL
      END IF

   ON CHANGE program
      IF loc.program IS NOT NULL AND loc.program > 0 AND loc.program <= amcr.getLength() THEN
	 LET k = loc.program MOD 10000
	 LET pp.wh_due = amcr[k].ddat
	 LET char16 = amcr[k].odat using "yyyy-mm-dd", " ", 
		      amcr[k].otim
	 LET pp.wh_till = char16
      ELSE
	 INITIALIZE pp.wh_due, pp.wh_till TO NULL
      END IF

   BEFORE FIELD wh_due
      IF loc.program IS NULL OR loc.program <= amcr.getLength() OR
                                loc.program >  10000 THEN
	 NEXT FIELD NEXT
      END IF

   AFTER FIELD wh_due
      IF pp.wh_due IS NOT NULL THEN
	 IF pp.wh_due < TODAY OR pp.wh_due > TODAY+7 THEN
	    CALL Infos("Ημερομηνία εκτός αποδεκτών ορίων.\n" ||
		       "Αποδεκτό είναι το διάστημα " ||
		       TODAY || " - " || TODAY+7)
	    NEXT FIELD wh_due
	 ELSE
	    IF loc.program > amcr.getLength() AND loc.program < 10000 THEN
	       LET pp.wh_till = CURRENT YEAR TO MINUTE + 15 UNITS MINUTE
	    END IF
	 END IF
      END IF

   AFTER INPUT 
      IF int_flag THEN EXIT INPUT END IF
      IF loc.program > 10000 THEN
	 CALL Infos("Η αντίστοιχη παραγγελία είναι ήδη καταχωρημένη\n" ||
		    "Εάν επιθυμείτε αλλαγές, ακυρώστε την παρούσα διαδικασία\n" ||
		    "και επιλέξτε την από τη λίστα των παραγγελιών")
	 NEXT FIELD program 
      END IF
      IF loc.program IS NULL THEN NEXT FIELD program END IF
      IF pp.wh_due   IS NULL THEN NEXT FIELD wh_due  END IF
      IF pp.wh_ent   IS NULL THEN NEXT FIELD wh_ent  END IF
      LET updated = TRUE            -- flag που σημαίνει πως πιθανώς έχουμε αλλαγές

END INPUT
IF int_flag THEN
   LET int_flag = FALSE
   RETURN wheadID, updated
END IF

--
--    Ολα ok ο χρήστης πάτησε ΟΚ-Ενημέρωση
--    Γίνεται Insert/Update καταλλήλως
--
IF wheadID = 0 THEN 

   LET pp.irowid = 0
   LET pp.datent = CURRENT YEAR TO MINUTE
   LET pp.datupd = CURRENT YEAR TO MINUTE
   IF loc.program > 0 AND loc.program <= amcr.getLength() THEN
      LET pp.wh_i1  = amcr[loc.program].recid
      LET pp.wh_typ = amcr[loc.program].dtyp
   ELSE
      LET pp.wh_i1  = NULL
      LET pp.wh_typ = "EXT"
   END IF

   WHENEVER ERROR CONTINUE 
   INSERT INTO webhead VALUES
	( pp.* )
   LET DBrc = SQLCA.SQLCODE
   LET pp.irowid = SQLCA.SQLERRD[2]
   WHENEVER ERROR STOP 

   IF DBrc < 0 THEN
      LET updated = FALSE
      CALL ShowMessage(4, "Error",
		       "Πρόβλημα στην καταχώρηση\n" ||
		       "Η νέα παραγγελία δεν δημιουργήθηκε\n" ||
		       "Κωδ.Λάθους: " || DBrc)
      RETURN wheadID, updated
   ELSE
      LET wheadID = pp.irowid
      IF pp.wh_cord IS NULL THEN
	 LET pp.wh_cord = "Π ", pp.irowid USING "<<<<<<"
	 UPDATE webhead SET
			wh_cord = pp.wh_cord
		  WHERE irowid  = pp.irowid
      END IF
   END IF

ELSE

   LET pp.datupd = CURRENT YEAR TO MINUTE
   IF loc.program > 0 AND loc.program <= amcr.getLength() THEN
      LET pp.wh_i1  = amcr[loc.program].recid
      LET pp.wh_typ = amcr[loc.program].dtyp
   ELSE
      LET pp.wh_i1  = NULL
      LET pp.wh_typ = "EXT"
   END IF

   WHENEVER ERROR CONTINUE 
   UPDATE webhead SET
		  wh_cord = pp.wh_cord,
		  wh_due  = pp.wh_due,
		  wh_ent  = pp.wh_ent,
		  wh_obs  = pp.wh_obs,
		  wh_i1   = pp.wh_i1,
		  wh_typ  = pp.wh_typ,
		  datupd  = pp.datupd
	    WHERE irowid = wheadID
   LET DBrc = SQLCA.SQLCODE
   WHENEVER ERROR STOP 

   IF DBrc < 0 THEN
      LET updated = FALSE
      CALL ShowMessage(4, "Error",
		       "Πρόβλημα στην ενημέρωση\n" ||
		       "Η ενημέρωση των στοιχείων απέτυχε\n" ||
		       "Κωδ.Λάθους: " || DBrc)
   ELSE
      LET updated = TRUE
   END IF

END IF

RETURN wheadID, updated

END FUNCTION          --  EDITwebhead(wheadID)






FUNCTION InTrcod(wheadID, MODE_Proswrines, MayUpd)
--
--    Προβολή/Edit γραμών array ειδών κάτω από την παραγγελία webhead.irowid = wheadID
--    Η flag MayUpd καθορίζει αν επιτρέπονται και μεταβολές
--    Το array των προϊόντων (asa04[].*) σε κάθε περίπτωση έχει ήδη διαβαστεί.
--    Επιστρέφει το "status" της ενέργειας του χρήστη:
--               TRUE: Edited ok
--              FALSE: Interrupted
--

DEFINE   wheadID              LIKE webhead.irowid,
         MODE_Proswrines      SMALLINT,
	 Original_MayUpd,
	 MayUpd, ok           SMALLINT,
	 i, j, totKol, k      INTEGER,
	 WeAreInPage          INTEGER,
	 btnPressed           SMALLINT,
	 needsRefresh         SMALLINT,
	 tabPageText          STRING


--
--    Επιβεβαιώνουμε ή όχι ότι είμαστε σε χρονική δυνατότητα αλλαγών
--
IF MODE_Proswrines AND MayUpd THEN 
   IF NOT InTimeUpdates(WORKING_WTIME, 1) THEN LET MayUpd = FALSE END IF
END IF

LET Original_MayUpd = MayUpd
IF NOT MODE_Proswrines THEN LET MayUpd = FALSE END IF
--
--    Initalize "σταθεράς"
--
CALL empty04.Clear()

--
--    Με το που μπαίνουμε στην f.() αυτή, θεωρείται πως έχουμε άμεσα πρόσβαση
--    στην πρώτη "ψευτοσελίδα", δηλ. στην SevenCategories[1].*
--    (Δεν χρειάζεται πριν την κλήση της InTrcod() να καλούμε LoadUIWebItems(),
--     καθώς αυτή θα κληθεί άμεσα εδώ, έτσι κι αλλιώς)
--
LET btnPressed = 1



LABEL STARTAGAIN:
-----------------

LET needsRefresh = FALSE
IF btnPressed IS NOT NULL THEN
   IF btnPressed < 100 THEN
      CALL LoadUIWebItems(SevenCategories[btnPressed].icat, MODE_Proswrines) RETURNING totKol
      LET tabPageText = SevenCategories[btnPressed].des || "  (" || totKol || ")"
      CALL ChangeElementsAtt("Page", "022", "text", tabPageText)
      --
      --    Αν επιστρέφουμε από πατημένο btn-all το οποίο είχε μασκάρει το MayUpd σε false
      --    να το επαναφέρουμε..
      --
      IF MODE_Proswrines AND Original_MayUpd THEN
         LET MayUpd = TRUE
      END IF
   ELSE
      --
      --    Ειδική Τιμή: 100
      --    Συμβολίζει την προβολή ΟΛΩΝ των ειδών που έχουν >0 ποσότητα παραγγελίας,
      --    ανεξαρτήτως κατηγορίας. READONLY κατάσταση
      --
      CALL LoadUIWebItems(0, MODE_Proswrines) RETURNING totKol
      LET tabPageText = "All ordered items  (" || totKol || ")"
      CALL ChangeElementsAtt("Page", "022", "text", tabPageText)
      LET MayUpd = FALSE
   END IF
END IF

LET WeAreInPage = btnPressed

DISPLAY ARRAY isa04 TO sa04.*
        ATTRIBUTE ( UNBUFFERED, CANCEL=FALSE )

   BEFORE DISPLAY
      CALL DIALOG.setActionHidden("lselect",1)     -- ¬«ό ε€ ε£­€ίε«  £ε€ ’’ά ’ε «¦¬¨εί §«ώ€«ͺ <Enter>.
						   -- £ε «¦€ «¨ό§¦ ¬«ό ’ε «¦¬¨εί ως Enter=Edit line
						   -- αφήνοντας ήσυχο το toolbar-Ok να είναι AcceptKey του DA
      CALL DIALOG.setActionActive("btn_1", 1)
      CALL DIALOG.setActionActive("btn_2", 1)
      CALL DIALOG.setActionActive("btn_3", 1)
      CALL DIALOG.setActionActive("btn_4", 1)
      CALL DIALOG.setActionActive("btn_5", 1)
      CALL DIALOG.setActionActive("btn_6", 1)
      CALL DIALOG.setActionActive("btn_7", 1)
      CALL DIALOG.setActionActive("lineedit", 1)
      CALL DIALOG.setActionActive("linedele", 1)
      CALL DIALOG.setActionActive("btn_all", 1)
      CASE
	 WHEN btnPressed = 1     CALL DIALOG.setActionActive("btn_1", 0)
	 WHEN btnPressed = 2     CALL DIALOG.setActionActive("btn_2", 0)
	 WHEN btnPressed = 3     CALL DIALOG.setActionActive("btn_3", 0)
	 WHEN btnPressed = 4     CALL DIALOG.setActionActive("btn_4", 0)
	 WHEN btnPressed = 5     CALL DIALOG.setActionActive("btn_5", 0)
	 WHEN btnPressed = 6     CALL DIALOG.setActionActive("btn_6", 0)
	 WHEN btnPressed = 7     CALL DIALOG.setActionActive("btn_7", 0)
	 WHEN btnPressed = 100   CALL DIALOG.setActionActive("btn_all", 0)
	                         CALL DIALOG.setActionActive("lineedit", 0)
	                         CALL DIALOG.setActionActive("linedele", 0)
      END CASE
      IF NOT MayUpd THEN
	 CALL DIALOG.setActionActive("lineedit", 0)
	 CALL DIALOG.setActionActive("linedele", 0)
      END IF
      LET btnPressed = NULL


   ON ACTION btn_1               -- Επιλογή της πρώτης στη σειρά κατηγορίας ειδών
      LET needsRefresh = TRUE
      LET btnPressed = 1
      EXIT DISPLAY

   ON ACTION btn_2 
      LET needsRefresh = TRUE
      LET btnPressed = 2
      EXIT DISPLAY

   ON ACTION btn_3 
      LET needsRefresh = TRUE
      LET btnPressed = 3
      EXIT DISPLAY

   ON ACTION btn_4 
      LET needsRefresh = TRUE
      LET btnPressed = 4
      EXIT DISPLAY

   ON ACTION btn_5 
      LET needsRefresh = TRUE
      LET btnPressed = 5
      EXIT DISPLAY

   ON ACTION btn_6 
      LET needsRefresh = TRUE
      LET btnPressed = 6
      EXIT DISPLAY

   ON ACTION btn_7 
      LET needsRefresh = TRUE
      LET btnPressed = 7
      EXIT DISPLAY

   ON ACTION btn_all 
      LET needsRefresh = TRUE
      LET btnPressed = 100
      EXIT DISPLAY

   ON ACTION _PageOrdhead
      --
      --    Φυσιολογικά, το action αυτό είναι ενεργό (δηλ. η αντίστοιχη σελίδα παραγγελιών εμφανής)
      --    ΜΟΝΟ όταν έχω μπεί για προβολή απλώς, από την σελίδα εκείνη.
      --    Το ξαναπάτημα της πρώτης σελίδας λοιπόν σημαίνει την επιθυμία να τερματίσουμε εδώ
      --    και να γυρίσουμε στο browsing των webhead
      --
      EXIT DISPLAY


   ON ACTION lselect
      --
      --    Enter στην γραμμή
      --
      LET i = ARR_CURR()
      LET j = SCR_LINE()
      IF MayUpd THEN
	 IF i > 0 AND asa04.getLength() >= i THEN
	    IF asa04[i].aiid IS NOT NULL THEN
	       CALL InputLineTrco(wheadID, i,j) RETURNING ok
	       --
	       --    Ενημέρωση οπτικής ένδειξης συνόλου κιβωτίων
	       --
	       IF ok THEN
		  CALL PageTabText_Refresh(WeAreinPage)
	       END IF
	       --
	    END IF
	 END IF
      END IF


   ON ACTION lineedit
      --
      --    Button "update" γραμμής: Λειτουργικά όμοιο με το Enter στη γραμμή
      --
      LET i = ARR_CURR()
      LET j = SCR_LINE()
      IF MayUpd THEN
	 IF i > 0 AND asa04.getLength() >= i THEN
	    IF asa04[i].aiid IS NOT NULL THEN
	       CALL InputLineTrco(wheadID, i,j) RETURNING ok
	       --
	       --    Ενημέρωση οπτικής ένδειξης συνόλου κιβωτίων
	       --
	       IF ok THEN
		  CALL PageTabText_Refresh(WeAreinPage)
	       END IF
	       --
	    END IF
	 END IF
      END IF

   ON ACTION linedele
      --
      --    Button "delete" γραμμής: Μηδενισμός της ποσότητας παραγγελίας
      --
      LET i = ARR_CURR()
      LET j = SCR_LINE()
      IF MayUpd THEN
	 IF i > 0 AND asa04.getLength() >= i THEN
	    IF asa04[i].aiid IS NOT NULL THEN
	       CALL ZeroLineTrco(wheadID, i,j) RETURNING ok
	       CALL PageTabText_Refresh(WeAreinPage)
	    END IF
	 END IF
      END IF

END DISPLAY

DISPLAY ARRAY empty04 TO sa04.* ATTRIBUTE ( CANCEL=FALSE )
   BEFORE DISPLAY
      EXIT DISPLAY
END DISPLAY

IF needsRefresh THEN GOTO STARTAGAIN END IF
--
--    Επανέφερε το original λεκτικό της σελίδας
--
CALL ChangeElementsAtt("Page", "022", "text", "Προιόντα")

END FUNCTION          --  InTrcod(wheadID, MODE_Proswrines, MayUpd)





FUNCTION PageTabText_Refresh(inPage)
--
--    Ενημέρωση οπτικής ένδειξης συνόλου κιβωτίων: Στο όνομα του current PageTab
--

DEFINE   inPage               INTEGER,
         totKol, k            INTEGER,
         tabPageText          STRING
  
--
--    Συνθήκη προστασίας, που δεν αναμένεται να ισχύει ΠΟΤΕ
--
IF inPage > 100 THEN RETURN END IF
--
LET totKol = 0
FOR k = 1 TO isa04.getLength()
   IF isa04[k].aqnt >= 0 THEN
      LET totKol = totKol + isa04[k].aqnt
   END IF
END FOR
LET tabPageText = SevenCategories[InPage].des || "  (" || totKol || ")"
CALL ChangeElementsAtt("Page", "022", "text", tabPageText)

END FUNCTION          --  PageTabText_Refresh(inPage)






FUNCTION ClearPagetrco()

CALL isa04.Clear()
DISPLAY ARRAY isa04 TO sa04.*
   BEFORE DISPLAY
      EXIT DISPLAY
END DISPLAY

END FUNCTION          --  ClearPagetrco()






FUNCTION LoadAllWebItems(wheadID)
--
--    Εργαζόμαστε για την παραγγελία webhead.irowid = wheadID
--    Φορτώνουμε στο global asa04[].* ΟΛΑ τα είδη του αντιστοίχου μηνός
--    Joined με τυχόν υπάρχοντα webtrco records.
--    Προετοιμάζουμε δηλ. τα UI arrays, ώστε να μπούμε σε διαχείριση ειδών της παραγγελίας
--

DEFINE   wheadID              LIKE webhead.irowid,
         pwi                  RECORD LIKE webitem.*,
	 loc                  RECORD
				 use, umn    SMALLINT,
				 till        LIKE webhead.wh_till
			      END RECORD,
	 wcqnt                LIKE webtrco.wc_qnt,
	 i                    INTEGER

--
--    Για να μην καθυστερούμε ΞΑΝΑδιαβάζοντας τα array όταν το έχουμε ήδη κάνει
--    για την ίδια παραγγελία,
--    bufferάρουμε την παραγγελία για την οποία μόλις δουλέψαμε, στην WORKING_WHID
--
IF WORKING_WHID IS NOT NULL AND WORKING_WHID = wheadID  THEN
   RETURN
END IF
--


CALL asa04.Clear()
SELECT YEAR(wh_due), MONTH(wh_due), wh_till INTO loc.use, loc.umn, loc.till FROM webhead WHERE
       irowid = wheadID
IF SQLCA.SQLCODE = NOTFOUND THEN RETURN END IF

DECLARE c_wi CURSOR FOR
   SELECT * FROM webitem WHERE
	  wi_who = pweb.wb_who AND
	  wi_sho = pweb.wb_sho AND
	  wi_use = loc.use AND
	  wi_umn = loc.umn AND
	  wi_avail > 0 AND
	  wi_cco = Racstu.as_cco
	  ORDER BY wi_who, wi_sho, wi_use, wi_umn, wi_cod, wi_cco

LET i = 0
FOREACH c_wi INTO pwi.*
   LET i = i+1
   LET asa04[i].aiid  = pwi.irowid
   LET asa04[i].ast1  = pwi.wi_st1
   LET asa04[i].ast2  = pwi.wi_st2
   LET asa04[i].acod  = pwi.wi_cod
   LET asa04[i].asms  = pwi.wi_sms
   LET asa04[i].aprc  = pwi.wi_prc
   LET asa04[i].anprc = pwi.wi_nprc
   LET asa04[i].aminq = pwi.wi_minq
   LET asa04[i].amaxq = pwi.wi_maxq
   LET asa04[i].abpk  = pwi.wi_bpk
   LET asa04[i].aqpro = pwi.wi_qpro
   LET asa04[i].amsg1 = pwi.wi_msg1
   --
   --    Λοιπά στοιχεία από items & webtrco
   --
   SELECT it_des INTO asa04[i].ades FROM items WHERE
	  it_cod = pwi.wi_cod
   SELECT MIN(irowid) INTO asa04[i].awid FROM webtrco WHERE
	  wc_head = wheadID AND wc_cod = pwi.wi_cod
   IF SQLCA.SQLCODE = NOTFOUND THEN LET asa04[i].awid = NULL END IF
   IF asa04[i].awid IS NOT NULL THEN
      SELECT wc_qnt INTO wcqnt FROM webtrco WHERE
	     irowid = asa04[i].awid
      LET asa04[i].aqnt = wcqnt
   ELSE
      LET asa04[i].aqnt = NULL
   END IF
END FOREACH
LET WORKING_WHID = wheadID
LET WORKING_WTIME= loc.till

END FUNCTION          --  LoadAllWebItems(wheadID)





FUNCTION LoadUIWebItems(Category, MODE_Proswrines)
--
--    Προετοιμάζει το UI global isa04[].*
--    φορτώνοντας του από το ήδη διαβασμένο asa04[].*
--    εκείνες ΜΟΝΟ τις γραμμές που αντιστοιχούν στα είδη
--    της κατηγορίας Category με την οποία θέλουμε στη συνέχεια να εργαστούμε
--
--    Ειδική τιμή Category=0  =>
--    Φόρτωσε ΟΛΑ τα είδη με παραγγελθείσα ποσότητα, ΑΝΕΞΑΙΡΕΤΩΣ κατηγορίας. Read Only MODE
--
--    Επιστρέφει - σε κάθε περίπτωση - το συνολικό πλήθος ποσότητας, που περιέχεται
--    στις κατασκευαζόμενες isa04 γραμμές
--

DEFINE   Category             INTEGER,
         MODE_Proswrines      SMALLINT,
	 i, j, retqnt         INTEGER

CALL isa04.Clear()
LET retqnt = 0
LET j = 0
IF Category > 0 THEN
   FOR i = 1 TO asa04.getLength()
      IF asa04[i].ast2 = Category AND
	 ( MODE_Proswrines OR asa04[i].aqnt > 0 ) THEN
	 LET j = j+1
	 LET isa04[j].* = asa04[i].*
	 IF isa04[j].aqnt >= 0 THEN
	    LET retqnt = retqnt + isa04[j].aqnt
	 END IF
      END IF
   END FOR
ELSE
   FOR i = 1 TO asa04.getLength()
      IF asa04[i].aqnt > 0 THEN
	 LET j = j+1
	 LET isa04[j].* = asa04[i].*
	 LET retqnt = retqnt + isa04[j].aqnt
      END IF
   END FOR
END IF
RETURN retqnt

END FUNCTION          --  LoadUIWebItems(Category, MODE_Proswrines)






FUNCTION InputLineTrco(wheadID, irow, srow)

DEFINE   wheadID              LIKE webhead.irowid,
         irow, srow, j        INTEGER,
	 ok, DBrc             SMALLINT,
	 imodulo              INTEGER,
	 linevalue            LIKE webtrco.wc_val,
	 wcstu1               LIKE webtrco.wc_stu1,
         loc                  RECORD             -- Ομοιο με το asa04[].*
				 aiid  LIKE webitem.irowid,
				 awid  LIKE webtrco.irowid,
				 ast1  LIKE webitem.wi_st1,
				 ast2  LIKE webitem.wi_st2,
				 acod  LIKE webitem.wi_cod,
				 ades  LIKE items.it_des,
				 asms  LIKE webitem.wi_sms,
				 aqnt  INTEGER,
				 aprc  LIKE webitem.wi_prc,
				 anprc LIKE webitem.wi_nprc,
				 aminq LIKE webitem.wi_minq,
				 amaxq LIKE webitem.wi_maxq,
				 abpk  LIKE webitem.wi_bpk,
				 aqpro LIKE webitem.wi_qpro,
				 amsg1 LIKE webitem.wi_msg1
			      END RECORD

--
--    Βρισκόμαστε στην παραγγελία webhead.irowid = wheadID
--    Τα προϊόντα όλα του τιμοκαταλόγου JOIN της παραγγελίας, έχουν ήδη διαβαστεί
--    στο global array asa04[].* (και της συγκεκριμένης input κατηγορίας στο isa04[].*).
--    Βρισκόμαστε στην γραμμή οθόνης srow του FE100.sa04.* και τρέχον είναι το
--    στοιχείο isa04[irow].*
--    Κληθήκαμε για να κάνουμε Input σε αυτήν την μοναδική γραμμή
--

LET ok = TRUE
LET loc.* = isa04[irow].*

INPUT loc.* WITHOUT DEFAULTS FROM sa04[srow].*
      ATTRIBUTE ( UNBUFFERED )

   BEFORE FIELD aqnt
      IF loc.amaxq <= 0 THEN
	 CALL ShowMessage(1, "Ελεγχος ποσότητας",
			  "Η παραγγελία του είδους " || loc.acod || "\n" ||
			  loc.ades || "\n" ||
			  "είναι μπλοκαρισμένη\n" ||
			  "Παρακαλώ επικοινωνήστε με το DC")
	 EXIT INPUT
      END IF

   AFTER INPUT
      IF int_flag THEN EXIT INPUT END IF
      IF loc.aqnt <= 0 THEN 
	 LET loc.aqnt = NULL
	 LET int_flag = TRUE
	 EXIT INPUT
      END IF
      IF loc.aqnt < loc.aminq THEN
	 CALL ShowMessage(1, "Ελεγχος ποσότητας",
			  "Η ποσότητα παραγγελίας διορθώθηκε στην ελάχιστη επιτρεπτή")
	 LET loc.aqnt = loc.aminq
      END IF
      IF loc.aqnt > loc.amaxq THEN
	 CALL ShowMessage(1, "Ελεγχος ποσότητας",
			  "Η ποσότητα παραγγελίας διορθώθηκε στην μέγιστη επιτρεπτή")
	 LET loc.aqnt = loc.amaxq
      END IF
      IF loc.abpk > 1 THEN
	 LET imodulo = loc.aqnt MOD loc.abpk
	 IF imodulo != 0 THEN
	    CALL ShowMessage(1, "Ελεγχος ποσότητας",
			     "Η ποσότητα παραγγελίας του είδους " || loc.acod || "\n" ||
			     loc.ades || "\n" ||
			     "οφείλει να είναι πολλαπλάσιο του " || loc.abpk)
	    NEXT FIELD aqnt
	 END IF
      END IF
      CASE
	 WHEN loc.aqnt < loc.aminq     LET wcstu1 = -1
	 WHEN loc.aqnt > loc.amaxq     LET wcstu1 =  1
	 OTHERWISE                     LET wcstu1 =  0
      END CASE

END INPUT

IF int_flag THEN
   LET int_flag = FALSE
   LET ok = FALSE
ELSE
   IF loc.awid IS NULL OR loc.awid = 0 THEN
      --
      --    Να προστεθεί μια νέα γραμμή webtrco
      --
      WHENEVER ERROR CONTINUE 
      LET linevalue = loc.aprc * loc.aqnt

      INSERT INTO webtrco
	   ( wc_head, wc_cod, wc_kol, wc_qnt, 
	     wc_st1,  wc_st2, wc_prc, wc_val,
	     wc_stu1 )
	     VALUES
	   ( wheadID, loc.acod, loc.aqnt, loc.aqnt, 
	     loc.ast1, loc.ast2, loc.aprc, linevalue,
	     wcstu1 )

      LET DBrc = SQLCA.SQLCODE
      LET loc.awid = SQLCA.SQLERRD[2]
      WHENEVER ERROR STOP 

      IF DBrc < 0 THEN GOTO FUNCENDS END IF
   ELSE
      --
      --    Να γίνει update μια υπάρχουσα γραμμή webtrco
      --
      WHENEVER ERROR CONTINUE 
      UPDATE webtrco 
		 SET wc_kol = loc.aqnt,
		     wc_qnt = loc.aqnt,
		     wc_val = wc_prc * loc.aqnt,
		     wc_stu1= wcstu1
	       WHERE irowid = loc.awid
      LET DBrc = SQLCA.SQLCODE
      WHENEVER ERROR STOP 

      IF DBrc < 0 THEN GOTO FUNCENDS END IF
   END IF

   --
   --    Συγχρονισμός program variables
   --
   LET isa04[irow].awid = loc.awid
   LET isa04[irow].aqnt = loc.aqnt
   FOR j = 1 TO asa04.getLength()
      IF asa04[j].acod = loc.acod THEN
	 LET asa04[j].awid = loc.awid
	 LET asa04[j].aqnt = loc.aqnt
	 EXIT FOR
      END IF
   END FOR
END IF


LABEL FUNCENDS:
---------------

IF DBrc < 0 THEN
   LET ok = FALSE
   CALL ShowMessage(2, "Update DB error", 
		    "Internal error " || DBrc)
END IF
RETURN ok

END FUNCTION          --  InputLineTrco(wheadID, irow, srow)






FUNCTION ZeroLineTrco(wheadID, irow, srow)

DEFINE   wheadID              LIKE webhead.irowid,
         irow, srow, j        INTEGER,
	 ok, DBrc             SMALLINT,
	 imodulo              INTEGER,
         loc                  RECORD             -- Ομοιο με το asa04[].*
				 aiid  LIKE webitem.irowid,
				 awid  LIKE webtrco.irowid,
				 ast1  LIKE webitem.wi_st1,
				 ast2  LIKE webitem.wi_st2,
				 acod  LIKE webitem.wi_cod,
				 ades  LIKE items.it_des,
				 asms  LIKE webitem.wi_sms,
				 aqnt  INTEGER,
				 aprc  LIKE webitem.wi_prc,
				 anprc LIKE webitem.wi_nprc,
				 aminq LIKE webitem.wi_minq,
				 amaxq LIKE webitem.wi_maxq,
				 abpk  LIKE webitem.wi_bpk,
				 aqpro LIKE webitem.wi_qpro,
				 amsg1 LIKE webitem.wi_msg1
			      END RECORD

--
--    Βρισκόμαστε στην παραγγελία webhead.irowid = wheadID
--    Τα προϊόντα όλα του τιμοκαταλόγου JOIN της παραγγελίας, έχουν ήδη διαβαστεί
--    στο global array asa04[].* (και της συγκεκριμένης input κατηγορίας στο isa04[].*).
--    Βρισκόμαστε στην γραμμή οθόνης srow του FE100.sa04.* και τρέχον είναι το
--    στοιχείο isa04[irow].*
--    Κληθήκαμε για να μηδενίζουμε την ποσότητα παραγγελίας αυτής της γραμμής
--

LET ok = TRUE
IF isa04[irow].aqnt IS NULL OR isa04[irow].aqnt = 0 OR 
   isa04[irow].awid IS NULL OR isa04[irow].awid = 0 THEN 
   RETURN ok 
END IF

--
--    Να γίνει delete μια υπάρχουσα γραμμή webtrco
--
WHENEVER ERROR CONTINUE 
DELETE FROM webtrco WHERE irowid = isa04[irow].awid
WHENEVER ERROR STOP 

LET DBrc = SQLCA.SQLCODE
IF DBrc < 0 THEN GOTO FUNCENDS END IF

--
--    Συγχρονισμός program variables
--
LET isa04[irow].awid = NULL
LET isa04[irow].aqnt = NULL
FOR j = 1 TO asa04.getLength()
   IF asa04[j].acod = isa04[irow].acod THEN
      LET asa04[j].awid = NULL
      LET asa04[j].aqnt = NULL
      EXIT FOR
   END IF
END FOR


LABEL FUNCENDS:
---------------

IF DBrc < 0 THEN
   LET ok = FALSE
   CALL ShowMessage(2, "Update DB error", 
		    "Internal error " || DBrc)
END IF
RETURN ok

END FUNCTION          --  ZeroLineTrco(wheadID, irow, srow)





FUNCTION Confirm_webhead(wheadID) 
--
--    Κατασκευή μιας ενιαίας (μάνας) παραγγελίας στο orhdr-ortrn
--    με βάση τα στοιχεία webhead.ID

--

DEFINE   wheadID                 LIKE webhead.irowid,
         pwh                     RECORD LIKE webhead.*,
         dt                      RECORD LIKE webtrco.*,
	 roh                     RECORD LIKE orhdr.*,
	 rot                     RECORD LIKE ortrn.*,
	 rna                     RECORD LIKE names.*,
	 rsh                     RECORD LIKE shops.*,
	 dueuse, dueumn          SMALLINT,
	 DBrc                    SMALLINT,
	 itfpa                   SMALLINT,
	 itdes                   CHAR(40),
	 msg                     CHAR(80),
	 retfpa                  RECORD 
				    fkey   SMALLINT,
				    fclass SMALLINT,
				    fpers  DECIMAL(3,1)
				 END RECORD,
	 updated                 INTEGER


LET updated = FALSE
SELECT * INTO pwh.* FROM webhead WHERE irowid = wheadID
IF SQLCA.SQLCODE = NOTFOUND THEN RETURN updated END IF

SELECT * INTO rna.* FROM names WHERE 
       na_key = pwh.wh_who
SELECT * INTO rsh.* FROM shops WHERE 
       sh_acc = 30 AND sh_acci = pwh.wh_who AND
       sh_sho = pwh.wh_sho

LET dueuse =  YEAR(pwh.wh_due)
LET dueumn = MONTH(pwh.wh_due)

CALL begin_wk()

--
--    orhdr
--

LET roh.oh_cco = Racstu.as_cco
LET roh.oh_acd = 30              LET roh.oh_who = pwh.wh_who
LET roh.oh_sho = pwh.wh_sho      LET roh.oh_dat = TODAY
LET roh.oh_due = pwh.wh_due      LET roh.oh_cord= pwh.wh_cord
LET roh.oh_msg = pwh.wh_obs[1,50] CLIPPED
LET roh.oh_trn = 32    
LET roh.oh_stu = "0000"          LET roh.oh_pc  = rna.na_fl1
LET roh.oh_pay =  rna.na_pay     LET roh.oh_tim = rna.na_tim
LET roh.oh_dis =  rna.na_dis     LET roh.oh_sal = rsh.sh_sal
LET roh.oh_vek =  rsh.sh_vek     LET roh.oh_dro = rsh.sh_dro
LET roh.oh_obs =  rsh.sh_tobs    
LET roh.oh_time=  CURRENT

IF roh.oh_pc != 2 AND roh.oh_pc != 4 THEN
   LET roh.oh_num = pwh.wh_cord
END IF

LET roh.oh_col = pwh.wh_i1
IF pwh.wh_i1 IS NOT NULL THEN
   LET roh.oh_way = 1
   SELECT mc_typ INTO roh.oh_acdi FROM mcrec WHERE irowid = pwh.wh_i1
   IF SQLCA.SQLCODE = NOTFOUND THEN LET roh.oh_acdi = NULL END IF
ELSE
   LET roh.oh_way = 2
END IF
--
--    Προτιμούμε σε κάθε περίπτωση να δίνουμε έναν χαρακτηρισμό στον
--    τύπο της παραγγελίας από το να μένει κενός..
--
IF roh.oh_acdi IS NULL THEN
   LET roh.oh_acdi = "Κ"
END IF

WHENEVER ERROR CONTINUE 

INSERT INTO orhdr 
     ( oh_cco, oh_num, oh_cord,oh_acd, 
       oh_col, oh_acdi,
       oh_who, oh_sho, oh_dat, oh_due, oh_sal, 
       oh_tim, oh_dis, oh_vek, oh_dro, oh_pc, 
       oh_msg,
       oh_obs, oh_trn, oh_pay, oh_stu, oh_time,
       oh_way )
       values
     ( roh.oh_cco, roh.oh_num, roh.oh_cord,roh.oh_acd, 
       roh.oh_col, roh.oh_acdi,
       roh.oh_who, roh.oh_sho, roh.oh_dat, roh.oh_due, roh.oh_sal, 
       roh.oh_tim, roh.oh_dis, roh.oh_vek, roh.oh_dro, roh.oh_pc, 
       roh.oh_msg,
       roh.oh_obs, roh.oh_trn, roh.oh_pay, roh.oh_stu, roh.oh_time,
       roh.oh_way )
LET DBrc = SQLCA.SQLCODE
LET roh.irowid = SQLCA.SQLERRD[2]

WHENEVER ERROR STOP 

IF DBrc < 0 THEN
   CALL rollback_wk()
   CALL ShowMessage(4, "Error",
		    "Αδυναμία εισαγωγής παραγγελίας\n" ||
		    "Internal error: " || DBrc)
   LET msg = "user:", pweb.wb_log CLIPPED, " Point:2119, Error:", DBrc
   CALL WEBERRORLOG(msg)
   GOTO FUNCENDS
END IF


--
--  ortrn
--

DECLARE c_details CURSOR WITH HOLD FOR
   SELECT * FROM webtrco WHERE
	  wc_head = wheadID
    ORDER BY wc_head, wc_st2, wc_cod


FOREACH c_details INTO dt.*

   INITIALIZE rot.* to null
   SELECT it_fpa, it_st1, it_st2, it_des
     INTO itfpa, rot.ot_st1, rot.ot_st2, itdes
     FROM items 
    WHERE it_cod = dt.wc_cod

   LET rot.irowid = 0               LET rot.ot_ohd = roh.irowid
   LET rot.ot_cco = roh.oh_cco      LET rot.ot_cod = dt.wc_cod
   LET rot.ot_qnt = dt.wc_qnt       LET rot.ot_fix = 0
   LET rot.ot_i_p = 0  
   LET rot.ot_prc = dt.wc_prc

   --
   --    Προσοχή:
   --    Παραλλαγή ειδικά κατασκευασμένη για παραγγελία McD, όπου Q = K
   --
   LET rot.ot_kol = rot.ot_qnt
   --

   --
   --    Ελεγχος καθοριζόμενου ποσοστού ΦΠΑ
   --
   CALL WhichFpa(itfpa, roh.oh_vek, 1) RETURNING retfpa.*
   IF retfpa.fkey IS NULL THEN
      CALL ShowMessage(4, "Error",
		       "Αδυναμία καταχώρησης είδους στην παραγγελία." ||
		       "Το είδος " || rot.ot_cod || "   " || itdes || "\n" ||
		       "δεν έγινε δυνατό να συμπεριληφθεί στην παραγγελία\n" ||
		       "λόγω προβλήματος στον ορισμό του συντελεστή ΦΠΑ\n" ||
		       "Παρακαλώ επικοινωνήστε με το DC")
      LET msg = "user:", pweb.wb_log CLIPPED, " Point:2167, Error: FPA notfound for ",
		rot.ot_cod
      CALL WEBERRORLOG(msg)
      CONTINUE FOREACH 
   END IF
   LET rot.ot_fpers = retfpa.fpers
   LET rot.ot_fpa   = retfpa.fkey
   {
   CALL CodDisCount(roh.oh_who, rot.ot_cod, rot.ot_qnt, roh.oh_due) 
	 RETURNING rot.ot_dis
   }
   LET rot.ot_dis = 0

   WHENEVER ERROR CONTINUE 

   INSERT INTO ortrn 
	( ot_ohd,    ot_cco,    ot_i_p,    
	  ot_cod,    ot_st1,    ot_st2,    ot_kol,    
	  ot_qnt,    ot_prc,    ot_fix,    ot_dis,    
	  ot_fpers,  ot_fpa,    ot_tkol,   ot_tqnt )
	  values
	( rot.ot_ohd,   rot.ot_cco, rot.ot_i_p, 
	  rot.ot_cod,   rot.ot_st1, rot.ot_st2, rot.ot_kol, 
	  rot.ot_qnt,   rot.ot_prc, rot.ot_fix, rot.ot_dis, 
	  rot.ot_fpers, rot.ot_fpa, 0, 0 )
   LET DBrc = SQLCA.SQLCODE
   WHENEVER ERROR STOP 

   IF DBrc < 0 THEN
      CALL rollback_wk()
      CALL ShowMessage(4, "Error",
		       "Αδυναμία εισαγωγής είδους στην παραγγελία !" ||
		       "Το είδος " || rot.ot_cod || "   " || itdes || "\n" ||
		       "δεν έγινε δυνατό να συμπεριληφθεί στην παραγγελία.\n" ||
		       "Παρακαλώ επικοινωνήστε με το DC\n" ||
		       "Internal error: " || DBrc)
      LET msg = "user:", pweb.wb_log CLIPPED, " Point:2209, Error:", DBrc
      CALL WEBERRORLOG(msg)
      GOTO FUNCENDS
   END IF


   --
   --    Ενημέρωση του μηνιαίου webitem με την αθροιστική ποσότητα
   --    που έχει παραγγείλει το κατάστημα από το είδος
   --
   WHENEVER ERROR CONTINUE 

   UPDATE webitem SET
		  wi_totq = wi_totq + rot.ot_qnt
	    WHERE wi_use = dueuse AND
		  wi_umn = dueumn AND
		  wi_cod = rot.ot_cod AND
		  wi_who = roh.oh_who AND
		  wi_sho = roh.oh_sho AND
		  wi_cco = roh.oh_cco
   LET DBrc = SQLCA.SQLCODE
   WHENEVER ERROR STOP 

   IF DBrc < 0 THEN
      CALL rollback_wk()
      CALL ShowMessage(4, "Error",
		       "Αδυναμία εισαγωγής είδους στην παραγγελία !" ||
		       "Το είδος " || rot.ot_cod || "   " || itdes || "\n" ||
		       "δεν έγινε δυνατό να συμπεριληφθεί στην παραγγελία.\n" ||
		       "Παρακαλώ επικοινωνήστε με το DC\n" ||
		       "Internal error: " || DBrc)
      LET msg = "user:", pweb.wb_log CLIPPED, " Point:1963, Error:", DBrc
      CALL WEBERRORLOG(msg)
      GOTO FUNCENDS
   END IF

END FOREACH 

{
--
--    Ενημέρωση mcords, εφόσον η παραγγελία εισήχθη σε αντιστοιχία με αυτήν
--
IF mco.irowid IS NOT NULL THEN
   UPDATE mcords SET 
		 mo_orhid = roh.irowid
	   WHERE irowid = mco.irowid
END IF
--
}

--
--    Ενημέρωση του webhead με το ID της παραγγελίας που κατασκευάστηκε
--
UPDATE webhead SET
	       wh_orh = roh.irowid,
	       wh_sent= CURRENT YEAR TO MINUTE
	 WHERE irowid = wheadID



LABEL FUNCENDS:
---------------

IF DBrc >= 0 THEN
   LET updated = TRUE
   CALL commit_wk()

   LET msg = "user:", pweb.wb_log CLIPPED, " Point:2239, CONFIRMED: orhdr.ID=", roh.irowid
   CALL WEBERRORLOG(msg)
   --
   --    Αποστολή ενημερωτικού email στον εσωτερικό υπεύθυνο του DC
   --
   CALL EmailDC(wheadID)
   --
END IF

RETURN updated

END FUNCTION          --  Confirm_webhead(wheadID)





FUNCTION InformNowLocked()
--
--    Η απώτατη ώρα οριστικοποίησης έχει παρέλθει για μια παραγγελία
--    Μήνυμα που ενημερώνει πως δεν μπορεί ο χρήστης πλέον να κάνει κάτι
--
CALL ShowMessage(2, "Κλειδωμένη παραγγελία",
		 "Δεν έχετε πλέον δικαίωμα μεταβολών στην παραγγελία\n" )

END FUNCTION          --  InformNowLocked()





FUNCTION InTimeUpdates(Vtill, Verbose)
--
--    Εχω δικαίωμα να τροποιήσω στοιχεία της προσωρινής webhead
--    ή πλέον η ώρα έχει περάσει;
--

DEFINE   Vtill          LIKE webhead.wh_till,
	 Verbose, ok    SMALLINT,
	 realup         DATETIME YEAR TO MINUTE

LET ok = TRUE
LET realup = CURRENT YEAR TO MINUTE - 1 UNITS MINUTE
IF Vtill <= realup THEN LET ok = FALSE END IF

IF NOT ok AND Verbose THEN CALL InformNowLocked() END IF
RETURN ok

END FUNCTION          --  InTimeUpdates()





FUNCTION InTimeUpdatesID(Vid, Verbose)

DEFINE   Vid            LIKE webhead.irowid,
	 Verbose, ok    SMALLINT,
	 ptill          LIKE webhead.wh_till

SELECT wh_till INTO ptill FROM webhead WHERE irowid = Vid AND wh_orh = 0
IF SQLCA.SQLCODE = NOTFOUND THEN RETURN FALSE END IF
CALL InTimeUpdates(ptill, Verbose) RETURNING ok
RETURN ok

END FUNCTION          --  InTimeUpdatesID(Vid, Verbose)





FUNCTION WhichFpa(ifpa, cvek, ComputeFpa)
--
--        Εχουμε ένα είδος/υπηρεσία με κωδ.ΦΠΑ ifpa    
--        και έναν πελάτη με καθεστώς ΦΠΑ cvek  
--        Παράλληλα, είμαστε σε παραστατικό δηλωμένο ότι υπολογίζει ή όχι ΦΠΑ.
--        ( Η παράμετρος ComputeFpa οφείλει να είναι η stctl.vathdr )
--        Ποιός είναι ο τελικός κωδ.ΦΠΑ και το ποσοστό που θα ισχύσει
--        κατά την πώληση αυτή ?
--        Η f() αυτή επιστρέφει τελικά ένα record με τα βασικότερα
--        fields του fpa.*
--        ...
--

DEFINE   ifpa        LIKE fpa.fkey,
	 cvek        LIKE names.na_vek,
	 ComputeFpa  INTEGER,
	 Vfpa        RECORD LIKE fpa.*,
	 retfpa      RECORD 
		        fkey   LIKE fpa.fkey,
		        fclass LIKE fpa.fclass,
		        fpers  LIKE fpa.fpers 
		     END RECORD
		  
INITIALIZE Vfpa.*, retfpa.* TO NULL
IF ifpa IS NULL OR cvek IS NULL THEN RETURN retfpa.* END IF

--
--    Οταν όχι ΦΠΑ, είναι το ίδιο με το να πούμε ότι ο πελάτης είναι
--    σε ειδικό καθεστώς 2  ( Εξαιρείται του ΦΠΑ )
--    ...
--
IF ComputeFpa = 0 THEN
   LET cvek = 2
END IF

SELECT * INTO Vfpa.* FROM fpa WHERE fpa.fkey = ifpa
IF SQLCA.SQLCODE = NOTFOUND THEN RETURN retfpa.* END IF
CASE cvek
   WHEN 0    EXIT CASE
   WHEN 1    SELECT * INTO Vfpa.* FROM fpa WHERE fpa.fkey = Vfpa.fek1
             IF SQLCA.SQLCODE = NOTFOUND THEN INITIALIZE Vfpa.* TO NULL END IF
             EXIT CASE
   WHEN 2    SELECT * INTO Vfpa.* FROM fpa WHERE fpa.fkey = Vfpa.fek2
             IF SQLCA.SQLCODE = NOTFOUND THEN INITIALIZE Vfpa.* TO NULL END IF
             EXIT CASE
   OTHERWISE EXIT CASE
END CASE

LET retfpa.fkey  = Vfpa.fkey
LET retfpa.fclass= Vfpa.fclass
LET retfpa.fpers = Vfpa.fpers
RETURN retfpa.*

END FUNCTION          --  WhichFpa(ifpa, cvek, ComputeFpa)





FUNCTION WEBERRORLOG(msg)

DEFINE   msg            CHAR(80)

CALL ERRORLOG(msg)

END FUNCTION          --  WEBERRORLOG(msg)





FUNCTION PrintOrder(wheadID)

DEFINE   wheadID              LIKE webhead.irowid,
         PageLength           INTEGER

CALL StartReport("223", "Εκτύπωση Παραγγελίας", 100, 9) RETURNING PageLength
IF PageLength <= 0 THEN RETURN END IF

START REPORT r_rep223 TO applic.richfile WITH
      LEFT MARGIN=0, TOP MARGIN=0, BOTTOM MARGIN=0, PAGE LENGTH=PageLength

OUTPUT TO REPORT r_rep223(wheadID)
FINISH REPORT r_rep223
CALL DisplayRptWebOut(223)

END FUNCTION          --  PrintOrder(wheadID)




REPORT r_rep223(rr)

--
--    Εκρός από την παράμετρο rr = webhead.ID που θα τυπωθεί,
--    λαμβάνει υπόψιν το global pweb.*  ( = CURRENT webuser )
--    από όπου λαμβάνει στοιχεία καταστήματος
--

DEFINE   rr                LIKE webhead.irowid,
         pwh               RECORD LIKE webhead.*,
	 pwt               RECORD LIKE webtrco.*,
	 tt                RECORD
			      who   CHAR(20),
			      sho   CHAR(20),
			      nam   CHAR(80),
			      adr   CHAR(80),
			      afm   CHAR(20),
			      doy   CHAR(80),
			      due   DATE,
			      cord  CHAR(20),
			      sent  LIKE webhead.wh_sent,
			      ent   LIKE webhead.wh_ent,
			      tqnt  INTEGER,
			      tval  DECIMAL(10,2)
			   END RECORD,
	 lr                RECORD
			      des   LIKE items.it_des,
			      sdes  CHAR(40),
			      sms   LIKE webwsms.wi_sms
			   END RECORD,
	 prev_st2          INTEGER,
	 totq_st2          INTEGER


FORMAT

FIRST PAGE HEADER

   LET prev_st2 = NULL


ON EVERY ROW

   SELECT * INTO pwh.* FROM webhead WHERE irowid = rr
   INITIALIZE tt.* TO NULL

   LET tt.who  = pwh.wh_who CLIPPED, "/", pwh.wh_sho USING "<<<&"

   SELECT MAX(ms_srt) INTO tt.sho FROM wms:mshop WHERE ms_ekk = pweb.wb_i1
   LET tt.nam = pweb.wb_nam
   LET tt.adr = pweb.wb_adr
   LET tt.afm = pweb.wb_afm
   LET tt.doy = pweb.wb_doy
   LET tt.due =  pwh.wh_due 
   LET tt.cord=  pwh.wh_cord
   LET tt.sent=  pwh.wh_sent
   LET tt.ent =  pwh.wh_ent

   SELECT SUM(wc_qnt), SUM(wc_val) INTO tt.tqnt, tt.tval FROM webtrco WHERE
	  wc_head = rr

   PRINT "[<HEADER1>]",
	 tt.who clipped, "|",
	 tt.sho clipped, "|",
	 tt.nam clipped, "|",
	 tt.adr clipped, "|",
	 tt.afm clipped, "|",
	 tt.doy clipped, "|",
	 tt.due using "dd/mm/yyyy", "|",
	 tt.cord clipped, "|",
	 tt.sent,         "|",
	 tt.ent clipped, "|",
	 tt.tqnt using "#####&", "|",
	 tt.tval using "#####&.&&"

   DECLARE c_dets CURSOR FOR
      SELECT * FROM webtrco WHERE wc_head = rr 
	     ORDER BY wc_head, wc_st2, wc_cod

   FOREACH c_dets INTO pwt.*

      SELECT it_des INTO lr.des FROM items WHERE it_cod = pwt.wc_cod
      IF SQLCA.SQLCODE = NOTFOUND THEN LET lr.des = NULL END IF
      SELECT wi_sms INTO lr.sms FROM webwsms WHERE wi_cod = pwt.wc_cod
      IF SQLCA.SQLCODE = NOTFOUND THEN LET lr.sms = NULL END IF

      IF prev_st2 IS NULL OR
	 prev_st2 IS NOT NULL AND prev_st2 != pwt.wc_st2 THEN
	 --
	 --    break Κατηγορίας
	 --
	 WHENEVER ERROR CONTINUE 
	 SELECT cdes INTO lr.sdes FROM wms:codtb WHERE
		ctab = 42 and ccod = pwt.wc_st2
	 WHENEVER ERROR STOP 
	 IF SQLCA.SQLCODE = NOTFOUND OR SQLCA.SQLCODE < 0 THEN LET lr.sdes = NULL END IF
	 SELECT SUM(wc_qnt) INTO totq_st2 FROM webtrco WHERE 
		wc_head = rr AND wc_st2 = pwt.wc_st2
	 PRINT "[<LINES1>]",    "|||||"      -- Λειτουργικά ισοδύναμο του SKIP 1 LINE
	 PRINT "[<LINES1>]",
	                        "|",
	       lr.sdes clipped, "|",
	                        "|",
	       "(", totq_st2 USING "<<<<<&", ")",
				"|",
	                        "|"
	 LET prev_st2 = pwt.wc_st2
      END IF

      PRINT "[<LINES1>]",
	    pwt.wc_cod clipped, "|",
	    lr.des     clipped, "|",
	    lr.sms     clipped, "|",
	    pwt.wc_qnt using "####&", "|",
	    pwt.wc_prc using "####&.&&", "|",
	    pwt.wc_val using "####&.&&"

   END FOREACH


END REPORT          --  r_rep223(rr)
      




{
function infosa()

define   ss          string,
	 fn          char(255)

let ss = "EMAIL=pas@logifer.gr\n" ||
	 "SUBJECT=Test from CRONOS\n" ||
	 "<BODY>\n" ||
	 "Ελληνικό κείμενο\n"||
	 "παντού και πάντα"
let fn = "MESSAGES/saveemail.txt"
call SaveStringIntoFile(ss,fn)

end function
}



FUNCTION EmailDC(wheadID)
--
--    Μια νέα παραγγελία, η wheadID, έχει οριστικοποιηθεί από τον χρήστη pweb.*
--    και έχει πλέον εισαχθεί στο wms σύστημα.
--    Να σταλεί ενημερωτικό μήνυμα στον υπεύθυνο του DC
--
--    Προτιμούμε λατινική γραφή για αποφυγή προβλημάτων encoding
--
--

DEFINE   wheadID              LIKE webhead.irowid,
         ss                   STRING,
	 fn                   CHAR(255),
	 loc                  RECORD
				 srt   CHAR(20),  
				 obs   LIKE webhead.wh_obs,
				 due   LIKE webhead.wh_due,
				 typ   CHAR(8),
				 who   LIKE webhead.wh_who,
				 sho   LIKE webhead.wh_sho,
				 sent  LIKE webhead.wh_sent
			      END RECORD


IF pweb.wb_dcml IS NULL THEN RETURN END IF
SELECT ".", wh_obs, wh_due, wh_typ, wh_who, wh_sho, wh_sent INTO loc.* FROM webhead WHERE
	irowid = wheadID
IF SQLCA.SQLCODE = NOTFOUND THEN RETURN END IF
SELECT MAX(ms_srt) INTO loc.srt FROM wms:mshop WHERE ms_ekk = pweb.wb_i1
IF SQLCA.SQLCODE = NOTFOUND OR loc.srt IS NULL THEN LET loc.srt = "." END IF
CASE
   WHEN loc.typ IS NULL       LET loc.typ = "(K)"
   OTHERWISE                  LET loc.typ = "(", loc.typ CLIPPED, ")"
END CASE

LET fn = "MESSAGES/noDC_", wheadID USING "<<<&&&", ".txt"
IF loc.obs IS NULL THEN LET loc.obs = "." END IF

LET ss = "EMAIL=" || pweb.wb_dcml || "\n" ||
	 "SUBJECT=" || "Web Order: " || loc.srt CLIPPED || "   " || loc.due || "\n" ||
	 "<BODY>\n" ||
	 loc.obs || ".\n" ||
	 "A new order " || loc.typ CLIPPED || " placed. \n" ||
	 "Store: " || loc.srt CLIPPED || "  " ||
	 loc.who CLIPPED || "/" || loc.sho || " \n" ||
	 "Delivery date: " || loc.due || "\n" ||
	 "\n" ||
	 "Order confirmation time: " || loc.sent || "\n" ||
	 "</BODY>"

CALL SaveStringIntoFile(ss,fn)

END FUNCTION          --  EmailDC(wheadID)





FUNCTION ReportTimok(Vuse, Vumn, AllorNew)
--
--    Η φιλοσοφία είναι:
--    Τυπώνουμε τον τιμοκατάλογο του καταστήματος που αντιπροσωπεύει ο global user pweb.*
--    Είναι τιμές ισχύος Vdat=1/Vumn/Vuse 
--    και περιλαμβάνουν AllorNew όλα τα είδη ή μόνο όσα έχουν αλλαγή τιμής
--    Βασιζόμαστε στο αρχείο webtimo το οποίο θεωρούμε έγκυρο και απόλυτα ενημερωμένο
--

DEFINE   Vuse, Vumn           SMALLINT,
         AllorNew             SMALLINT,            -- 1:All    2:NewPrices
         Vdat                 DATE,
	 loc                  RECORD
				 use, umn    SMALLINT,
				 tim         SMALLINT,
				 fpa         SMALLINT
			      END RECORD,
	 pp                   RECORD LIKE webtimo.*,
         PageLength           INTEGER,
	 rr                   RECORD
				 dst2     CHAR(40),
				 cod      CHAR(10),
				 des      CHAR(40),
				 ltn      CHAR(40),
				 prc      DECIMAL(8,2),
				 fpa      LIKE fpa.fpers,
				 dif      DECIMAL(6,2),
				 vdt      DATE,
				 cau      INTEGER
			      END RECORD

LET Vdat = MDY(Vumn, 1, Vuse)

LET loc.use =  YEAR(Vdat)
LET loc.umn = MONTH(Vdat)

CALL StartReport("221", "Εκτύπωση Τιμοκαταλόγου", 100, 9) RETURNING PageLength
IF PageLength <= 0 THEN RETURN END IF

START REPORT r_rep221 TO applic.richfile WITH
      LEFT MARGIN=0, TOP MARGIN=0, BOTTOM MARGIN=0, PAGE LENGTH=PageLength


--
--    Διάβασε τον κωδ. τιμοκαταλόγου του πελάτη
--
SELECT na_tim INTO loc.tim FROM names WHERE na_key = pweb.wb_who
IF SQLCA.SQLCODE = NOTFOUND THEN LET loc.tim = 1 END IF
--

DECLARE c_repi CURSOR FOR
   SELECT * FROM webtimo WHERE
          wt_tim = loc.tim AND
	  wt_use = loc.use AND
	  wt_umn = loc.umn AND
	  wt_cco = Racstu.as_cco 
	  ORDER BY wt_tim, wt_use, wt_umn, wt_st2, wt_cod

FOREACH c_repi INTO pp.*
   --
   --    Για κάθε είδος
   --
   IF AllorNew = 2 AND pp.wt_nprc = 0 THEN CONTINUE FOREACH END IF
   --

   --
   --    Απέρριψε τα είδη που δεν είναι available στο κατάστημα αυτό
   --
   SELECT irowid FROM webitem WHERE
	  wi_use = loc.use AND
	  wi_umn = loc.umn AND
	  wi_cod = pp.wt_cod AND
	  wi_who = pweb.wb_who AND
	  wi_sho = pweb.wb_sho AND
	  wi_cco = Racstu.as_cco AND
	  wi_avail > 0
   IF SQLCA.SQLCODE = NOTFOUND THEN CONTINUE FOREACH END IF
   --

   SELECT cdes INTO rr.dst2 FROM wms:codtb WHERE ctab = 42 AND ccod = pp.wt_st2
   IF SQLCA.SQLCODE = NOTFOUND THEN LET rr.dst2 = NULL END IF

   LET rr.cod = pp.wt_cod
   SELECT it_des, it_ltn, it_fpa INTO rr.des, rr.ltn, loc.fpa FROM items WHERE it_cod = pp.wt_cod
   IF SQLCA.SQLCODE = NOTFOUND THEN INITIALIZE rr.des, rr.ltn, loc.fpa TO NULL END IF

   LET rr.prc = pp.wt_cprc
   LET rr.vdt = pp.wt_cdat

   SELECT fpers INTO rr.fpa FROM fpa WHERE fkey = loc.fpa
   IF SQLCA.SQLCODE = NOTFOUND THEN LET rr.fpa = NULL END IF

   LET rr.dif = pp.wt_diff
   LET rr.cau = pp.wt_caus

   OUTPUT TO REPORT r_rep221(Vdat, AllorNew, rr.*)

END FOREACH

FINISH REPORT r_rep221
CALL DisplayRptWebOut(221)


END FUNCTION          --  ReportTimok(Vuse, Vumn, AllorNew)





REPORT r_rep221(Vdat, AllorNew, rr)

DEFINE   Vdat                 DATE,
	 AllorNew             SMALLINT,
         rr                   RECORD
				 dst2     CHAR(40),
				 cod      CHAR(10),
				 des      CHAR(40),
				 ltn      CHAR(40),
				 prc      DECIMAL(8,2),
				 fpa      LIKE fpa.fpers,
				 dif      DECIMAL(6,2),
				 vdt      DATE,
				 cau      INTEGER
			      END RECORD,
	 tit1, tit2, tit3     CHAR(60)


OUTPUT

   TOP MARGIN 0
   LEFT MARGIN 0 
   PAGE LENGTH 3


ORDER EXTERNAL BY rr.dst2


FORMAT

FIRST PAGE HEADER

   LET tit1 = "PRICE LIST OF :  ", Vdat USING "mmm yyyy"
   IF AllorNew = 2 THEN
      LET tit2 = "PRICE CHANGES ONLY"
   ELSE
      LET tit2 = NULL
   END IF
   LET tit3 = NULL

   PRINT "[<HEADER1>]",
	 tit1 clipped, "|",
	 tit2 clipped, "|",
	 tit3 clipped


ON EVERY ROW

   PRINT "[<LINES1>]",
	 rr.dst2 clipped, "|",
	 rr.cod  clipped, "|",
	 rr.des  clipped, "|",
	 rr.ltn  clipped, "|",
	 rr.prc USING "###&.&&", "|",
	 rr.fpa USING "#&", "|",
	 rr.dif USING "---&.&&", "|",
	 rr.vdt USING "dd/mm/yy","|",
	 rr.cau USING "#"

END REPORT          --  r_rep221(Vdat, AllorNew, rr)
