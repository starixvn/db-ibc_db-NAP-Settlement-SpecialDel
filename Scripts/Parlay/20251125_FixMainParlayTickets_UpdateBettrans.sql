/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*	
	Creator: Helen
	Date: 20251125
	DB: DBSIG/bodb02

	Revisions:
		- 20251125@Helen: running ticket for parlay, sub already move to 14  [Redmine:#0000]
	Run on: SITEDB1

*/	
USE bodb02
GO

DECLARE @refnos_29				VARCHAR(MAX) = '',
		@MainParlay_MaxPO		VARCHAR(MAX) = NULL

CREATE TABLE #tblMainTicket
(
	TransId		BIGINT
	,Refno		BIGINT
)
INSERT INTO #tblMainTicket (transid, refno)
SELECT 457368430245314578, 28585526890070019

SELECT @refnos_29 = @refnos_29 + CONVERT(VARCHAR(50),refno) + '|' + CONVERT(VARCHAR(50),transid) + ','
FROM #tblMainTicket
		
EXEC dbo.NAP_Admin_Calculate_MP_broker
	@matchdate = '2025-11-24' -- main transid + refno: refno|transid,refno|transid...
	, @strXML	   = @refnos_29
	, @mode	   = '29'
	, @IsCalculateBalance = 1
	, @AffectedTransIds = @MainParlay_MaxPO OUTPUT
		
--Insert max payout queue
IF ISNULL(@MainParlay_MaxPO, '') <> ''
BEGIN
	EXEC dbo.NAP_Set_CustLimitBetQueue_Insert_Parlay
		@TransIds = @MainParlay_MaxPO
END
		
	
