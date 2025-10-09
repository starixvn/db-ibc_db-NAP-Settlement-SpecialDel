/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_BetTicket14_Insert]
(
	  @TransIds          VARCHAR(MAX) = NULL	
)
AS
/*	
	Created by: 20250919@July
	Task: [TVS] Manage Void Service - Correct summary ticket 19999 [Redmine: #238091]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20250919@July: Create new SP [Redmine:#238091]

	Param's explanation:
		--Capture before tickets in bettrans14
*/
BEGIN
	SET NOCOUNT ON

	DECLARE	@SiteDBGroupID			SMALLINT
		   ,@BeingBalanceUpDate		VARCHAR(255)
		   ,@BalanceUpDate			DATETIME
		   ,@InvalidTransIds		VARCHAR(MAX) = ''
		   ,@BalanceUpTransIds		VARCHAR(MAX) = ''

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	
	DECLARE @tmpTransIdList AS TABLE (TransId BIGINT)
	
	INSERT INTO @tmpTransIdList (TransId)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	SELECT @BeingBalanceUpDate = VValue
    FROM dbo.MBUSettings WITH (NOLOCK) 
	WHERE VName = 'BeingBalanceUpDate'

	SELECT @BalanceUpDate = VValue
    FROM dbo.MBUSettings WITH (NOLOCK) 
	WHERE VName = 'BalanceUpDate'

	CREATE TABLE #validTransId (
		transid			BIGINT PRIMARY KEY
		,bettype		SMALLINT
		,matchid		INT
		,winlostdate	DATETIME
		,custid			INT	
		,SiteDBGroupID  SMALLINT
	)

	INSERT INTO #validTransId (
		transid
		,bettype
		,matchid
		,winlostdate
		,custid
		,SiteDBGroupID
		)
	SELECT b.transid
		,bettype
		,matchid
		,winlostdate
		,custid
		,SiteDBGroupID
	FROM @tmpTransIdList t
		INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.transid
	WHERE b.SiteDBGroupID = @SiteDBGroupID
	
	IF @BeingBalanceUpDate IS NOT NULL 
		AND EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE winlostdate < @BalanceUpDate)
	BEGIN
		SELECT @BalanceUpTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50))
										FROM #validTransId t
										WHERE winlostdate < @BalanceUpDate
										FOR XML PATH('')), 1, 1, ''), '')
	END

	-- Invalid transId
	SELECT @InvalidTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM @tmpTransIdList t
										WHERE NOT EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE transid = t.transid)
										FOR XML PATH('')), 1, 1, ''), '')
	
	IF ISNULL(@InvalidTransIds,'') <> '' OR ISNULL(@BalanceUpTransIds,'') <> ''
	BEGIN
		SELECT @InvalidTransIds AS InvalidTransIds
		      ,@BalanceUpTransIds AS BalanceUpTransIds

		RETURN;
	END

	SELECT @InvalidTransIds AS InvalidTransIds
		  ,@BalanceUpTransIds AS BalanceUpTransIds

	TRUNCATE TABLE TVS_BetTicket14

	INSERT INTO TVS_BetTicket14 (TransId, CustId, Winlostdate, statusID, status, SettlementTime, 
								stake, actual_stake, winlost, awinlost, mwinlost, swinlost,
								playercomm, comm, acomm, scomm, betdaqid)
	SELECT b.TransId, b.CustId, b.Winlostdate, statusID, status, SettlementTime, 
		stake, actual_stake, winlost, awinlost, mwinlost, swinlost,
		playercomm, comm, acomm, scomm, betdaqid
	FROM #validTransId v
		INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON v.transid = b.transid

	DROP TABLE #validTransId
END		
GO


