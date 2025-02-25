/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RecoverVS2_Validation]
(
	@TransIds	VARCHAR(MAX)
	,@Resources	VARCHAR(MAX)
	,@ErrorCode 	INT = 0 OUTPUT
	,@ErrorMsg	NVARCHAR(200) = '' OUTPUT
)
AS
/*  
	Created by: 20250220@Max  
	Task: [TVS] Recover ticket of Virtual Sports 2 [Redmine: #212323]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02	    

	Revisions:  		
		- 20250220@Max: [TVS] Recover ticket of Virtual Sports 2 [Redmine: #212323]			

	Param's Explanation:		
		- @TransIds : Main transids.
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Action_Recal			VARCHAR(100)  = 'Re-Cal'
		  , @Action_Refund			VARCHAR(100)  = 'Refund'				
		  , @Movebetdate			DATETIME
		  , @spName					VARCHAR(500) = OBJECT_NAME(@@PROCID)
	
	DECLARE @SiteDBGroupID		SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
			
	CREATE TABLE #tblTransIds (transid BIGINT)	  	
	DECLARE @tmpBettype			TABLE(pfID SMALLINT, BetType SMALLINT PRIMARY KEY (BetType))
	
	--> parse @TransIds
	INSERT INTO #tblTransIds (transid)
	SELECT	t.value
	FROM STRING_SPLIT(@TransIds, ',') t					
		
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrorCode = 99, @ErrorMsg = 'No ticket found.'
			
		RETURN
	END	
		
	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

	--> Return data to web					
	SELECT  r.transid
		,b.custid
		,b.statusID
		,b.winlost
		,b.awinlost
		,b.mwinlost
		,b.swinlost
		,b.stake
		,b.odds
		,b.modds
		,b.ExtraInfo
		,b.currency
		,b.actual_stake
		,b.adiscount
		,b.apositiontaking
		,b.discount
		,b.mpositiontaking
		,b.playerdiscount
		,b.sdiscount
		,b.spositiontaking
		,b.bettype
		,b.betteam
		,b.comstatus
		,b.oddstype
		,CASE WHEN mt.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
		,rs.pfID AS ProfileID
		,b.SiteDBGroupID
		,b.oddsid
		,z.creator AS CreatorBackup
		,CASE WHEN m.eventstatus = 'completed'
					THEN CASE
							WHEN m.betstatus LIKE '%' + 'Refund' + '%' THEN @Action_Refund
							ELSE @Action_Recal
							END
			ELSE NULL
		END AS [Action]
		,b.matchid
	FROM #tblTransIds r
		INNER JOIN dbo.zzzbettrans z WITH (NOLOCK) ON z.transid = r.transid
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = r.transid
		INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid
		CROSS APPLY (
			SELECT DISTINCT p.pfID,p.Bettype
			FROM STRING_SPLIT(@Resources,',') AS rs
				INNER JOIN SettlementSpecialBettypeProfile p WITH(NOLOCK) ON rs.value = p.ResourceID AND p.sporttype = m.sporttype
			WHERE p.BetType = b.bettype
		)rs
		LEFT JOIN dbo.MarkedTransaction mt WITH (NOLOCK) ON mt.TransId = r.transid
	WHERE m.sporttype IN (198,177)
		AND m.eventdate > @Movebetdate
		AND b.statusID = 102
		AND b.SiteDBGroupID = @SiteDBGroupID

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrorCode = 99, @ErrorMsg = 'No ticket found.'
	END
	
	DROP TABLE #tblTransIds

	SET NOCOUNT OFF	
END
GO