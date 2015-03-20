INSERT INTO letter (module, code, name, title, content, message_transport_type)
VALUES ('circulation','ODUE','Avviso per i ritardi','Avviso per i ritardi','Salve <<borrowers.firstname>> <<borrowers.surname>>,\n\nSecondo le nostre registrazioni, hai dei prestiti in ritard.La biblioteca non dà multe per i ritardi, ma ti chiederemmo di restituirli o di rinnovarli il prima possibile presso la biblioteca:\n\n<<branches.branchname>>\n<<branches.branchaddress1>>\n<<branches.branchaddress2>> <<branches.branchaddress3>>\nTel:: <<branches.branchphone>>\nFax: <<branches.branchfax>>\nEmail: <<branches.branchemail>>\n\nSe ti sei registrato e hai una login con una password e quei prestiti sono rinnovabili, puoi provare a rinnovarli online. Se il prestito ha un ritardo superiore a 30 giorni, probabilmente non puoi rinnovarli.\n\nRisultano in ritardo:\n\n<item>"<<biblio.title>>" di <<biblio.author>>, <<items.itemcallnumber>>, codice a barre: <<items.barcode>> Multa: <<items.fine>></item>\n\nGrazie per l\'attenzione.\n\nLo staff della <<branches.branchname>> \n', 'email'),
('claimacquisition','ACQCLAIM','Sollecito al fornitore','Sollecito al fornitore','Salve <<aqbooksellers.name>>\r\n<<aqbooksellers.address1>>\r\n<<aqbooksellers.address2>>\r\n<<aqbooksellers.address3>>\r\n<<aqbooksellers.address4>>\r\n<<aqbooksellers.phone>>\r\n\r\n Questi ordini non ci sono giunti:\r\n\r\n<order>Ordernumber <<aqorders.ordernumber>> (<<aqorders.title>>) (<<aqorders.quantity>> ordinati) ($<<aqorders.listprice>> l\'uno).</order>', 'email'),
('serial','RLIST','Routing List','Routing List','Caro <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nQuesta pubblicazione è ora disponibile:\r\n\r\n<<biblio.title>>, <<biblio.author>> (<<items.barcode>>)\r\n\r\nPassa a prenderla presso il banco distribuzione.', 'email'),
('members','ACCTDETAILS','Messaggio per i nuovi utenti registrati','Messaggio per i nuovi utenti registrati.','Salve <<borrowers.title>> <<borrowers.firstname>> <<borrowers.surname>>.\r\n\r\nI dettagli del tuo nuovo account per la biblioteca sono:\r\n\r\nLogin:  <<borrowers.userid>>\r\nPassword: <<borrowers.password>>\r\n\r\nSe hai domande o problemi sul tuo account, contattaci a questo indirizzo e-mail: youremailadmin@library.it.\r\nGrazie di tutto\r\n\r\nLo staff della biblioteca\r\n', 'email'),
('circulation','DUE','Avviso restituzione (copia singola)','Avviso restituzione (copia singola)','Salve <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nQuesto prestito è ora in ritardo:\r\n\r\n<<biblio.title>>, <<biblio.author>> (<<items.barcode>>)', 'email'),
('circulation','DUEDGST','Avviso restituzione (digest)','Avviso restituzione (digest)','Hai <<count>> prestiti da retituire', 'email'),
('circulation','PREDUE','Preavviso scadenza prestito','Preavviso scadenza prestito','Salve <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nQuesti prestiti stanno per scadere:\r\n\r\n<<biblio.title>>, <<biblio.author>> (<<items.barcode>>)', 'email'),
('circulation','PREDUEDGST','Preavviso scadenza prestiti (digest)','Preavviso scadenza prestiti (digest)','Hai <<count>> prestiti che scadranno tra poco', 'email'),
('circulation','RENEWAL','Item Renewals','Item Renewals','The following items have been renewed:\r\n----\r\n<<
biblio.title>>\r\n----\r\nThank you for visiting <<branches.branchname>>.', 'email'),
('reserves', 'HOLD', 'Prenotazione disponibile per il ritiro', 'Prenotazione disponibile per il ritiro a <<branches.branchname>>', 'Salve <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nHai una prenotazione disponibili per il ritiro fino al <<reserves.waitingdate>>:\r\n\r\nTitolo: <<biblio.title>>\r\nAutore: <<biblio.author>>\r\nCopia n. : <<items.copynumber>>\r\nPresso: <<branches.branchname>>\r\n<<branches.branchaddress1>>\r\n<<branches.branchaddress2>>\r\n<<branches.branchaddress3>>\r\n<<branches.branchcity>> <<branches.branchzip>>', 'email'),
('reserves', 'HOLD', 'Prenotazione disponibile per il ritiro (stampa)', 'Prenotazione disponibile per il ritiro (stampa)', '<<branches.branchname>>\r\n<<branches.branchaddress1>>\r\n<<branches.branchaddress2>>\r\n\r\n\r\nPrenotazione disponibile per il ritiro\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n<<borrowers.firstname>> <<borrowers.surname>>\r\n<<borrowers.address>>\r\n<<borrowers.city>> <<borrowers.zipcode>>\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n<<borrowers.firstname>> <<borrowers.surname>> <<borrowers.cardnumber>>\r\n\r\nHai una prenotazione disponibili per il ritiro fino al <<reserves.waitingdate>>:\r\n\r\nTitolo: <<biblio.title>>\r\nAutore: <<biblio.author>>\r\nCopia n. : <<items.copynumber>>\r\n', 'print'),
('circulation','CHECKIN','Restituzione (Digest)','Restituzione','Questi prestiti sono stati restituiti:\r\n----\r\n<<biblio.title>>\r\n----\r\nGrazie.', 'email'),
('circulation','CHECKOUT','Prestiti','Prestiti','Ti sono stati dati in prestito:\r\n----\r\n<<biblio.title>>\r\n----\r\nGrazie da parte di <<branches.branchname>>.', 'email'),
('reserves', 'HOLDPLACED', 'Prenotazione di una copia', 'Prenotazione di una copia','Una prenotazione è stata fatta su una copia di : <<biblio.title>> (<<biblio.biblionumber>>) dall\'utente <<borrowers.firstname>> <<borrowers.surname>> (<<borrowers.cardnumber>>).', 'email'),
('suggestions','ACCEPTED','Suggerimento d\'acquisto accettato', 'Suggerimento d\'acquisto accettato','Salve <<borrowers.firstname>> <<borrowers.surname>>,\n\nHai suggerito di acquistare <<suggestions.title>> di <<suggestions.author>>.\n\nLa biblioteca ha revisionato il suggerimento oggi. La copia verrà ordinato il più presto possibile. Riceverai un\'email quando l\'ordine sarà completato e una altra mail quanto arriverà in biblioteca.\n\nSe hai domande, scrivici pure all\' email <<branches.branchemail>>.\n\nGrazie di tutto,\n\n<<branches.branchname>>', 'email'),
('suggestions','AVAILABLE','Suggerimento d\'acquisto disponibile', 'Suggerimento d\'acquisto disponibile','Salve <<borrowers.firstname>> <<borrowers.surname>>,\n\nHai suggerito di acquistare <<suggestions.title>> di <<suggestions.author>>.\n\nTi informiamo che la copia è arrivata in biblioteca.\n\nSe hai domande, scrivici pure all\' email <<branches.branchemail>>.\n\nGrazie di tutto,\n\n<<branches.branchname>>', 'email'),
('suggestions','ORDERED','Suggerimento d\'acquisto ordinato', 'Suggerimento d\'acquisto ordinato','Salve <<borrowers.firstname>> <<borrowers.surname>>,\n\nHai suggerito di acquistare <<suggestions.title>> di <<suggestions.author>>.\n\nTi informiamo che l\'ordine è stata inviato al fornitore della biblioteca. Dovrebbe arrivare in poco tempo, poi verrà aggiunto alla collezione della biblioteca.\n\nRiceverai un\'altra email quando sarà disponibile.\n\nSe hai domande, scrivici pure all\' email <<branches.branchemail>>\n\nGrazie di tutto,\n\n<<branches.branchname>>', 'email'),
('suggestions','REJECTED','Suggerimento d\'acquisto rifiutato', 'Suggerimento d\'acquisto rifiutato','Salve <<borrowers.firstname>> <<borrowers.surname>>,\n\nHai suggerito di acquistare <<suggestions.title>> di <<suggestions.author>>.\n\na biblioteca ha revisionato il suggerimento oggi e ha deciso di non seguire il suggerimento.\n\nLa motivazione è: <<suggestions.reason>>\n\nSe hai domande, scrivici pure all\' email <<branches.branchemail>>.\n\nGrazie di tuttp,\n\n<<branches.branchname>>', 'email');
INSERT INTO letter (module, code, name, title, content, is_html)
VALUES ('circulation','ISSUESLIP','Ricevuta di prestito','Ricevuta di prestito', '<h3><<branches.branchname>></h3>
Prestito a <<borrowers.title>> <<borrowers.firstname>> <<borrowers.initials>> <<borrowers.surname>> <br />
(<<borrowers.cardnumber>>) <br />

<<today>><br />

<h4>Prestito</h4>
<checkedout>
<p>
<<biblio.title>> <br />
Codice a barre: <<items.barcode>><br />
Data di scadenza: <<issues.date_due>><br />
</p>
</checkedout>

<h4>Ritardi</h4>
<overdue>
<p>
<<biblio.title>> <br />
Codice a barre: <<items.barcode>><br />
Data di scadenza: <<issues.date_due>><br />
</p>
</overdue>

<hr>

<h4 style="text-align: center; font-style:italic;">Novità</h4>
<news>
<div class="newsitem">
<h5 style="margin-bottom: 1px; margin-top: 1px"><b><<opac_news.title>></b></h5>
<p style="margin-bottom: 1px; margin-top: 1px"><<opac_news.new>></p>
<p class="newsfooter" style="font-size: 8pt; font-style:italic; margin-bottom: 1px; margin-top: 1px">Inserite il <<opac_news.timestamp>></p>
<hr />
</div>
</news>', 1),
('circulation','ISSUEQSLIP','Ricevuta (sintetica)','Ricevuta (sintetica)', '<h3><<branches.branchname>></h3>
Prestato/i a <<borrowers.title>> <<borrowers.firstname>> <<borrowers.initials>> <<borrowers.surname>> <br />
(<<borrowers.cardnumber>>) <br />

<<today>><br />

<h4>Prestati oggi</h4>
<checkedout>
<p>
<<biblio.title>> <br />
Codice a barre: <<items.barcode>><br />
Data di scadenza: <<issues.date_due>><br />
</p>
</checkedout>', 1),
('circulation','RESERVESLIP','Reserve Slip','Ricevuta (prenotazione)', '<h5>Data: <<today>></h5>

<h3> Trasferita a/Prenotata in <<branches.branchname>></h3>

<h3><<borrowers.surname>>, <<borrowers.firstname>></h3>

<ul>
    <li><<borrowers.cardnumber>></li>
    <li><<borrowers.phone>></li>
    <li> <<borrowers.address>><br />
         <<borrowers.address2>><br />
         <<borrowers.city >>  <<borrowers.zipcode>>
    </li>
    <li><<borrowers.email>></li>
</ul>
<br />
<h3>Opere prenotate</h3>
<h4><<biblio.title>></h4>
<h5><<biblio.author>></h5>
<ul>
   <li><<items.barcode>></li>
   <li><<items.itemcallnumber>></li>
   <li><<reserves.waitingdate>></li>
</ul>
<p>Note:
<pre><<reserves.reservenotes>></pre>
</p>
', 1),
('circulation','TRANSFERSLIP','Ricevuta (trasferimento)','Ricevuta (trasferimento)', '<h5>Data: <<today>></h5>

<h3>Transferita a<<branches.branchname>></h3>

<h3>Opera</h3>
<h4><<biblio.title>></h4>
<h5><<biblio.author>></h5>
<ul>
   <li><<items.barcode>></li>
   <li><<items.itemcallnumber>></li>
</ul>', 1);
INSERT INTO `letter` (`module`,`code`,`branchcode`,`name`,`is_html`,`title`,`content`)
VALUES (
'members',  'OPAC_REG_VERIFY',  '',  'Opac Self-Registration Verification Email',  '1',  'Verify Your Account',  'Hello!

Your library account has been created. Please verify your email address by clicking this link to complete the signup process:

http://<<OPACBaseURL>>/cgi-bin/koha/opac-registration-verify.pl?token=<<borrower_modifications.verification_token>>

If you did not initiate this request, you may safely ignore this one-time message. The request will expire shortly.'
);

INSERT INTO  letter (module, code, branchcode, name, is_html, title, content)
VALUES ('members', 'SHARE_INVITE', '', 'Invito per condividere una lista', '0', 'Condivisione lista <<listname>>', 'Salve,

Uno degli utenti della biblioteca, <<borrowers.firstname>> <<borrowers.surname>>, ti invita condividere una lista <<listname>> all\'interno dell\'Opac.

Per accedere a questa lista clicca sull\'URL che segue o copia-incolla l\'URL nel tuo browser.

<<shareurl>>

Nel caso tu non sia registrato nella biblioteca o non voglia accettare quest\'invito, allora ignora questa email. Nota anche che l\'invito scade in 2 settimane.

Grazie di tutto

Lo staff della biblioteca.'
);
INSERT INTO  letter (module, code, branchcode, name, is_html, title, content)
VALUES ( 'members', 'SHARE_ACCEPT', '', 'Notifica di condivisione lista accetata', '0', 'Condivisione alla lista <<listname>> accettata', 'Salve,

Ti informiamo che l\'utente <<borrowers.firstname>> <<borrowers.surname>> ha accettato il tuo invito a condividere la tua lista <<listname>> .

Grazie di tutto

Lo staff della biblioteca.'
);

INSERT INTO letter(module, code, branchcode, name, title, content, message_transport_type)
VALUES ('acquisition', 'ACQ_NOTIF_ON_RECEIV', '', 'Notification on receiving', 'Order received', 'Dear <<borrowers.firstname>> <<borrowers.surname>>,\n\n The order <<aqorders.ordernumber>> (<<biblio.title>>) has been received.\n\nYour library.', 'email')
