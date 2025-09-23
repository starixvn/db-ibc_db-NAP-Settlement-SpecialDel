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
		   ,@IsBeingBalanceUpDate	BIT
		   ,@InvalidTransIds		VARCHAR(MAX) = ''
		   ,@BalanceUpDate			DATETIME

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
		,StatusId		INT
		,bettype		SMALLINT
		,matchid		INT
		,betfrom		NVARCHAR(4)
		,winlostdate	DATETIME
		,betdaqid		BIGINT
		,custid			INT	
		,betid			BIGINT
		,SiteDBGroupID  SMALLINT
	)

	INSERT INTO #validTransId (
		transid
		,StatusId
		,bettype
		,matchid
		,betfrom
		,winlostdate
		,betdaqid
		,custid
		,SiteDBGroupID
		,betid
		)
	SELECT b.transid
		,statusID
		,bettype
		,matchid
		,betfrom
		,winlostdate
		,betdaqid
		,custid
		,SiteDBGroupID
		,betid
	FROM @tmpTransIdList t
		INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.transid
	WHERE b.statusID NOT IN (101, 102, 103)
		AND b.betfrom <> 'P'
		AND b.SiteDBGroupID = @SiteDBGroupID
	
	IF @BeingBalanceUpDate IS NOT NULL 
		AND EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE winlostdate = @BalanceUpDate)
	BEGIN
		SET @IsBeingBalanceUpDate = 1 --Show tooltip: Being BalanceUp Date
		
		SELECT @IsBeingBalanceUpDate AS IsBeingBalanceUpDate
		RETURN;
	END

	-- Invalid transId
	SELECT @InvalidTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM @tmpTransIdList t
										WHERE NOT EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE transid = t.transid)
										FOR XML PATH('')), 1, 1, ''), '')
	IF @InvalidTransIds IS NOT NULL 
	BEGIN
		SELECT @InvalidTransIds AS InvalidTransIds
		RETURN;
	END

	INSERT INTO TVS_BetTicket14 (TransId, CustId, Winlostdate, statusID, status, SettlementTime, 
								stake, actual_stake, winlost, awinlost, mwinlost, swinlost,
								playercomm, comm, acomm, scomm, betdaqid)
	SELECT TransId, CustId, Winlostdate, statusID, status, SettlementTime, 
		stake, actual_stake, winlost, awinlost, mwinlost, swinlost,
		playercomm, comm, acomm, scomm, betdaqid
	FROM dbo.bettrans14 b WITH (NOLOCK)
	WHERE EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE TransId = b.TransId)

	DROP TABLE #validTransId
END		
GO


