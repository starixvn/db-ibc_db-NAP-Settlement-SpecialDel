/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefund_MatchChecking_Ticket
	@MatchId		INT
	,@sporttype		SMALLINT
	,@ResourceIds	VARCHAR(500) = ''
	--,@TypeId		TINYINT
	,@ErrCode 		INT = 0 OUTPUT
	,@ErrMsg 		NVARCHAR(200) = '' OUTPUT
AS
/*
	Creator: 20220719@Louisa
	Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBTXN/bodb02
	Revisions:		
		- 20201216@Louisa: Separate SP from NAP_Set_AutoRefund_MatchChecking [Redmine:#175251]

	Param's explaination: 
		- @TypeId:  1 - Auto refund single
				   10 - Auto refund parlay

*/
BEGIN
	
	SET NOCOUNT ON

	DECLARE  @IsExistSettledTicket	BIT = 0
			, @IsCentral			BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
		

		CREATE TABLE #tmpResultDetail (ResourceId VARCHAR(20), SettlementStatusId TINYINT, HomeValue VARCHAR(50), AwayValue VARCHAR(50), ResultSetting	TINYINT,  MatchType VARCHAR(1), bettype SMALLINT, betid BIGINT  )			
		
		IF @sporttype = 1 AND EXISTS (SELECT TOP 1 1  FROM  dbo.bettrans bt WITH(NOLOCK) 
							WHERE bt.matchid = @MatchId 
								AND bt.statusID IN (111,112,113,103) 
								AND ISNULL(bt.betdaqid,0) <> -2
								AND bt.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bt.SiteDBGroupID END
							)
		BEGIN
					SELECT @ErrCode = 	1001070   
						,@ErrMsg  = 	'Auto refund child match failed: settled tickets exist.'
					RETURN
		END

		ELSE IF @sporttype = 9
		BEGIN
			INSERT INTO #tmpResultDetail ( bettype, betid ) 
			SELECT DISTINCT sp.Bettype, sp.betid
			FROM dbo.SettlementSpecialBettypeProfile sp (NOLOCK)
				INNER JOIN  STRING_SPLIT(@ResourceIds, ',') f  ON sp.ResourceID = f.value
			WHERE sp.SportType = @sportType
				AND sp.SettleType ='MNL'

			SELECT @ErrCode = 	1001070   
				  ,@ErrMsg  = 	'Auto Refund failed: settled tickets exist.' 				  
			FROM ( 
					SELECT TOP 1 b.transid
					FROM dbo.bettrans  b (nolock)
						INNER JOIN #tmpResultDetail tmp ON b.Bettype = tmp.bettype AND (b.Betid = 0 OR b.betid = tmp.betid)
					WHERE b.matchid = @matchid
						AND statusid  IN ( 111, 112, 113, 103 )
						AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				) b

			IF ISNULL(@ErrCode, 0) = 0
			BEGIN
				SELECT @ErrCode = 	1001070   
					  ,@ErrMsg  = 	'Auto Refund failed: settled tickets exist.'		  
				FROM (  
						SELECT TOP 1 bm.transid
						FROM dbo.bettransm  bm (nolock)
							INNER JOIN #tmpResultDetail tmp ON bm.Bettype = tmp.bettype AND (bm.betcheck = 0 OR bm.betcheck = tmp.betid)
						WHERE bm.matchid = @matchid
							AND statusid  IN ( 111, 112, 113, 103 )
							AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
						) b
			END

		END
END
GO
