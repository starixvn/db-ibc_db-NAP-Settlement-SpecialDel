/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_Set_CashoutSel]
	 @MatchId INT
	,@SelectedResources VARCHAR(MAX)
	,@Action					VARCHAR(20)		
	,@DeterminedType			INT			= 0
AS
/*
	Created by: 20220531@Kathy
	Task: get list CO ticket [Redmine:#173361]
	DB:DBTXN.BODB02

	Revisions:
		- 20220531@Kathy: get list CO ticket [Redmine:#173361]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20230515@Aries: Apply Settle Determined for Basketball [Redmine:#184124]
		- 20230515@Aries: Apply Settle Instant for Basketball [Redmine:#184124]
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]
		
	Param's Explanation:
		* @SelectedResources= '<Resources>
									<Resource Id="M1" />
									<Resource Id="M2" />
							   </Resources>'
	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @handle		INT
			,@IsCentral	BIT
			,@DummyResourceIds		VARCHAR(MAX) = ''
			,@DummyResourceResults	VARCHAR(MAX) = ''

	DECLARE @tmpResources TABLE(ResourceID VARCHAR(20), Bettype SMALLINT, BetId BIGINT)
	DECLARE @tmpBettype TABLE(BetType SMALLINT, BetID BIGINT,SDTResourceId VARCHAR(20), SDTpfId SMALLINT, HomeValue VARCHAR(2000), AwayValue VARCHAR(2000),PRIMARY KEY (BetType,BetID))


	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO @tmpResources(ResourceID, Bettype, BetId)
	SELECT Id, sp.BetType, sp.BetID
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)) AS tbl
		INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK) ON sp.ResourceID = tbl.Id
	WHERE	sp.SportType = 2	
	EXEC sp_xml_removedocument @handle


	IF @DeterminedType > 0 
	BEGIN
		INSERT INTO @tmpBettype(Bettype, BetID,SDTResourceId, SDTpfId)
		SELECT DISTINCT s.BetType, s.BetID, s.SDTResourceId,s.SDTpfId
		FROM	dbo.SettlementSpecialBettypeProfile AS s WITH(NOLOCK)
		WHERE s.SportType = 2
			AND 1 = CASE WHEN @Action = 'CAL' AND ISNULL(s.DeterminedType,0) & @DeterminedType > 0 THEN 1
						 WHEN @Action = 'REFUND' AND ISNULL(s.SDTRefund,0) & @DeterminedType > 0 THEN 1
						 ELSE 0
					END

		SELECT	@DummyResourceIds = STRING_AGG(CAST(tbl.SDTResourceId AS VARCHAR(MAX)), ',')
		FROM (SELECT DISTINCT SDTResourceId FROM @tmpBettype) AS tbl

		EXEC dbo.NAP_Set_DummyResourceResult
					 @MatchID               = @MatchID
					,@SportType             = 2
					,@Action				= @Action
					,@IsDetermined          = 1
					,@WebResourceResult     = @SelectedResources
					,@DummyResourceIds      = @DummyResourceIds
					,@DummyResourceResults  = @DummyResourceResults OUTPUT

		EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
		UPDATE bt
		SET  bt.HomeValue = tbl.Home
			,bt.AwayValue = tbl.Away
		FROM @tmpBettype AS bt
			INNER JOIN OPENXML(@handle,'root/r',1) WITH( Id VARCHAR(20),Home VARCHAR(2000),Away VARCHAR(2000)) AS tbl ON tbl.Id = bt.SDTResourceId
		EXEC sp_xml_removedocument @handle
	END

	INSERT INTO @tmpBettype(Bettype, BetID,SDTpfId)
	SELECT Bettype, BetID, NULL
	FROM @tmpResources AS rs
	WHERE NOT EXISTS (SELECT 1 FROM @tmpBettype AS bt WHERE  rs.Bettype = bt.Bettype AND  rs.BetID = bt.BetID)

	SELECT	b.transid
		   ,b.custid
		   ,CASE WHEN b.statusID = 103	AND (@Action IN ('CAL','UNDO') OR (@Action = 'REFUND' AND @DeterminedType > 0 AND m.modds IS NOT NULL))	THEN 'Undo'
				 WHEN b.statusID != 103 AND @Action = 'REFUND'	AND (@DeterminedType = 0 OR  (@DeterminedType > 0 AND m.modds IS NULL))	THEN 'Void'
			END [Action]
	FROM	dbo.bettrans b WITH(NOLOCK)
		CROSS APPLY(SELECT TOP 1 t.SDTpfId, t.HomeValue, t.AwayValue
					FROM @tmpBettype AS t
					WHERE b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID)) AS sr
		OUTER APPLY dbo.f_Set_SDT_OS_modds(sr.SDTpfId, b.betteam, b.hdp1, sr.HomeValue, sr.AwayValue, b.transdesc, 0) AS m
	WHERE	b.matchid = @MatchId
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		AND ISNULL(b.betdaqid,0) = -2
		AND b.statusID <> 102
		AND 1 = CASE WHEN b.statusID = 103	AND (@Action IN ('CAL','UNDO') OR (@Action = 'REFUND'  AND @DeterminedType > 0 AND m.modds IS NOT NULL))	THEN 1
					 WHEN b.statusID != 103 AND @Action = 'REFUND'	AND (@DeterminedType = 0 OR  (@DeterminedType > 0 AND m.modds IS NULL))	THEN 1
					 ELSE 0
				END
END


GO


