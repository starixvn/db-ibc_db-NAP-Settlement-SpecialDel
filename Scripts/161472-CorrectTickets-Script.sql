/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/* 
	Created:20210911@Helen
    Task: Correct ticket on [RedmineId:#161472]
	DB: DBTXN/bodb02
*/
USE bodb02
go
UPDATE b
SET 
		ruben = 0
		,STATUS = 'running'
		,statusID = 0
		,winlost = 0
		,awinlost = 0
		,mwinlost = 0
		,swinlost = 0
		,playercomm = 0
		,comm = 0
		,acomm = 0
		,scomm = 0
		,statuswinlost = NULL
		,odds = CASE WHEN b.bettype = 376 THEN b.oddsspread ELSE b.odds END
FROM dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) 
WHERE transid in (113208393469,
113208310481,
113207438631,
113207437117,
113208312917,
113208667441,
113208562056,
113208199429,
113207910093,
113205140405,
113208368725,
113208192539,
113208386133,
113208390976,
113208254891,
113207889939,
113207892378,
113207897911,
113207899406)