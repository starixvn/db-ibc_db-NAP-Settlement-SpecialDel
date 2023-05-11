/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayout_MatchInfo
	@MatchIds	VARCHAR(MAX)
AS
/*
	Created: 20160825@Kathy
	Task: Autop payout - Get match info
	DB: DBPRO/BODB02
	
	Revision:
		- 20161003@Bobby: #65002 - Implement Auto CAL page info: update Instant match status
		- 20161027@Bobby: #66376 - Don't show Confirm button when match is completed
		- 20161118@Kathy: Changes on Auto Settlement [Redmine:#67328]
		- 20160509@Kathy: Fast Market integration [Remine:#56367]
		- 20161128@Bobby: #67760 - Implement IS for FGLG bet types
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180131@Benjamin: Add "SourceID = 100" to filter correct score from Suspender before confirm [Redmine:#86964]
		- 20180206@Kathy: Add new column IsFTCalculated to determine whether match calculated FT or not [Redmine:#86964]
		- 20180208@Benjamin: Implement to determine AutoIntant and ManualInstant [Redmine:#86964]
		- 20180530@Benjamin: Convert HomeValue, AwayValue to number before comparing [Redmine:#86964]
		- 20181002@Kathy: Add New Status "Result Pending" and "Under Settlement" [Redmine:#102028]
		- 20181127@Vicky: Add MTD Hold status & Postponed [Redmine: #104948]
		- 20190620@Kathy: Remove auto betradar bettypes [Redmine:#109584]
		- 20201027@Louisa: Add new settlement status - Hold Key bit[7] - [Redmine:#143441]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]

	Param's explanation: 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xml XML
	DECLARE @tblMatchInQueue TABLE (
		 MatchId						INT
		,SingleStatus					TINYINT
		,GoalRecordFTResultStatusId		TINYINT
		,HTFGNGResultStatusId			TINYINT
		,FTFGNGResultStatusId			TINYINT
		,HTLGResultStatusId				TINYINT
		,FTLGResultStatusId				TINYINT
		
		,HTStatus						BIT
		,FTStatus						BIT
		,CalculationType				TINYINT DEFAULT(0)
		,HomeValue					VARCHAR(50) DEFAULT('0')
		,AwayValue					VARCHAR(50) DEFAULT('0')
		,InstantStatusId				TINYINT DEFAULT(0)
		,InstantKey					INT
		,InstantScoreDiff				TINYINT DEFAULT(0)
		,InstantHomeScoreBefore		INT
		,InstantAwayScoreBefore		INT
		,InstantGoalRecordBefore	VARCHAR(50)
	)
	
	SET @xml = CONVERT(XML, REPLACE('<root><r m="' + @MatchIds + '"/></root>', ',','"/><r m="'))

	INSERT INTO @tblMatchInQueue (MatchId)
	SELECT	T.C.value('./@m', 'int') -- matchid
	FROM	@xml.nodes('/root/r') as [T](C) --T: table, C: column
	
	--get more error from AutoPayoutResult to refresh on main page	
	INSERT INTO @tblMatchInQueue(MatchId, SingleStatus, CalculationType)
	SELECT	MatchId
			,3 AS SingleStatus_FailedAuto
			,CalculationType
	FROM	dbo.AutoPayoutResult a WITH(NOLOCK)
	WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @tblMatchInQueue q WHERE q.MatchId = a.MatchId)
			AND a.ModifiedDate > DATEADD(MINUTE, -1, GETDATE())
			AND StatusId = 3
	GROUP BY MatchId,CalculationType
	
	--get more instant match with new score confirmation
	;WITH instantScore AS (
		SELECT MatchId, HomeValue, AwayValue, CalculationType, IsConfirmed, SourceID, InstantKey, RowIdx
		FROM (
			SELECT 
				prd.MatchId
				, prd.HomeValue
				, prd.AwayValue
				, prd.TypeId AS CalculationType
				, prd.IsConfirmed
				, prd.SourceID
				, prd.ProviderResultDetailId AS InstantKey
				, ROW_NUMBER() OVER(
					PARTITION BY prd.matchid
					ORDER BY ProviderResultDetailId DESC
				) AS RowIdx
				
			FROM dbo.ProviderResultDetail prd WITH (NOLOCK)
				INNER JOIN dbo.match m WITH(NOLOCK) 
				ON prd.matchid = m.matchid
				INNER JOIN dbo.league l WITH(NOLOCK) 
				ON m.leagueid = l.leagueid
				
			WHERE prd.TypeId IN (101, 102)
				AND prd.SourceID = 100 --#86964
				AND NOT EXISTS (SELECT TOP 1 1 FROM @tblMatchInQueue q WHERE q.MatchId = prd.MatchId)
				AND m.sporttype = 1 
				AND m.eventstatus = 'running' 
				AND 2 & ISNULL(m.AutoSetting,l.AutoSetting) = 2
				AND m.SettlementStatus & 87 = 0 --bit 1,2,3,5,7
		) AS t 
		WHERE RowIdx IN (1, 2)
	)
	INSERT INTO @tblMatchInQueue(MatchId, HomeValue, AwayValue,InstantStatusId,CalculationType,InstantKey, InstantScoreDiff)
	SELECT temp.MatchId
		,temp.HomeValue
		,temp.AwayValue
		,1 AS InstantStatusId
		,temp.CalculationType
		,temp.InstantKey
		--,CASE WHEN (chk.matchID > 0 AND  (temp.HomeValue < chk.HomeValue OR temp.AwayValue < chk.AwayValue) ) THEN 1 ELSE 0 END AS InstantScoreDiff
		,CASE WHEN (chk.matchID > 0 AND  (CAST(ISNULL(temp.HomeValue, 0) AS INT)) < (CAST(ISNULL(chk.HomeValue, 0) AS INT)) OR (CAST(ISNULL(temp.AwayValue, 0) AS INT)) < (CAST(ISNULL(chk.AwayValue, 0) AS INT))) THEN 1 ELSE 0 END AS InstantScoreDiff
	FROM instantScore AS temp
		LEFT JOIN instantScore AS chk 
			ON temp.matchID = chk.matchID AND chk.RowIdx = 2
		OUTER APPLY(
			SELECT TOP 1 *
			FROM dbo.AutoPayoutResult aps WITH(NOLOCK)
			WHERE	temp.matchid = aps.matchID
					AND temp.CalculationType = aps.CalculationType
					AND temp.HomeValue 	= aps.HomeValue
					AND temp.AwayValue 	= aps.AwayValue
			ORDER BY ModifiedDate DESC
		) aps
			
	WHERE temp.RowIdx = 1
		AND (
			aps.StatusId IS NULL --not confirm yet
			OR (aps.StatusId = 3 --FAILED to re-confirm			
			    
					   --#86964
						 AND (NOT EXISTS (SELECT 1 FROM dbo.AutoPayoutResult a WITH(NOLOCK)  --SUCCESSS by Others (Auto/Manual)
									   WHERE a.matchid			  = aps.matchID
									   AND a.CalculationType	  = aps.CalculationType
									   AND a.HomeValue		  = aps.HomeValue
									   AND a.AwayValue		  = aps.AwayValue
									   AND a.StatusId		  = 2)
							 
							 OR EXISTS (SELECT 1 FROM (SELECT TOP 2 MatchID, ModifiedDate, StatusID, -- Not Calculate yet
												    ROW_NUMBER() OVER( PARTITION BY aps.matchid ORDER BY ModifiedDate DESC) AS RowIdx
												  FROM dbo.AutoPayoutResult aps WITH(NOLOCK)
												  WHERE aps.matchid		   = temp.matchID
												    AND aps.CalculationType = temp.CalculationType
												    AND aps.HomeValue	   = temp.HomeValue
												    AND aps.AwayValue	   = temp.AwayValue
									  ) AS T1
									  LEFT JOIN (SELECT TOP 2 MatchID, ModifiedDate, StatusID,
											     ROW_NUMBER() OVER( PARTITION BY aps.matchid ORDER BY ModifiedDate DESC) AS RowIdx
											   FROM dbo.AutoPayoutResult aps WITH(NOLOCK)
											   WHERE aps.MatchID		 = temp.MatchID
												AND aps.CalculationType	 = temp.CalculationType
												AND aps.HomeValue		 = temp.HomeValue
												AND aps.AwayValue		 = temp.AwayValue
										  ) AS T2 ON T1.MatchID= T2.MatchID AND T2.RowIdx = 2
										  WHERE T1.RowIdx = 1
										  AND (T1.StatusID <> 2 AND T1.ModifiedDate > T2.ModifiedDate) --last update still calculate failed
									  )
							 )
					  )--#86964

			OR (aps.StatusId = 2 
				--AND temp.IsConfirmed = 0
				) --abnormal case -> re-calculate
		)
			
	;WITH cteAutoResultDetail
	AS(
		SELECT	CASE 							
					WHEN isFGLG = 1 AND GroupId IN (1,3) THEN '127_'
					WHEN isFGLG = 1 AND GroupId IN (2,4) THEN '14_'
					WHEN IsUsedGoalRecordValue = 1 THEN '08'					
					ELSE CAST(BetType AS VARCHAR(20))
				END AS ResourceId
				,GroupId
				,IsUsedGoalRecordValue
		FROM	dbo.f_Set_GetGroupBettypes()
		WHERE	IsUsedGoalRecordValue = 1
	)
	UPDATE	m
		SET 
			GoalRecordFTResultStatusId = rs.GoalRecordFTResultStatusId
			,FTFGNGResultStatusId = rs.FTFGNGResultStatusId
			,FTLGResultStatusId = rs.FTLGResultStatusId
			,HTFGNGResultStatusId = rs.HTFGNGResultStatusId
			,HTLGResultStatusId = rs.HTLGResultStatusId
	FROM	@tblMatchInQueue m
		CROSS APPLY (
			SELECT	TOP 1 r.matchid
					,MIN(CASE WHEN c.groupId IN (2,4) AND c.IsUsedGoalRecordValue = 1 THEN r.ResultStatusID END) AS GoalRecordFTResultStatusId
					,MIN(CASE WHEN r.ResourceId = '127F' THEN r.ResultStatusId END) AS HTFGNGResultStatusId
					,MIN(CASE WHEN r.ResourceId = '14F' THEN r.ResultStatusId END) AS FTFGNGResultStatusId

					,MIN(CASE WHEN r.ResourceId = '127L' THEN r.ResultStatusId END) AS HTLGResultStatusId
					,MIN(CASE WHEN r.ResourceId = '14L' THEN r.ResultStatusId END) AS FTLGResultStatusId
			FROM	dbo.ResultDetail r WITH(NOLOCK)
				INNER JOIN cteAutoResultDetail c
					ON	r.ResourceId LIKE c.ResourceId
			WHERE	r.MatchId = m.MatchId
			GROUP BY r.MatchId		
		) rs
		
	UPDATE	m 
		SET	HTStatus = a.HTStatus
			,FTStatus = a.FTStatus
	FROM	@tblMatchInQueue m
		CROSS APPLY (
			SELECT	TOP 1 a.MatchId
					,MAX(CASE WHEN a.CalculationType = 1 THEN 1 ELSE 0 END) AS HTStatus
					,MAX(CASE WHEN a.CalculationType = 2 THEN 1 ELSE 0 END) AS FTStatus
			FROM	dbo.AutoPayoutResult a WITH(NOLOCK)
			WHERE	m.MatchId = a.MatchId
					AND a.CalculationType BETWEEN 1 AND 2
					AND a.StatusId IN (1,2)
			GROUP BY a.MatchId
		) a
	
	--Update score to confirm for match being existed in queue
	;WITH InstMatchConfirm AS (
		SELECT MatchId, HomeValue, AwayValue, CalculationType, IsConfirmed, InstantKey, RowIdx
		FROM (
			SELECT 
				prd.MatchId
				, prd.HomeValue
				, prd.AwayValue
				, prd.TypeId AS CalculationType
				, prd.IsConfirmed
				, prd.SourceID
				, prd.ProviderResultDetailId AS InstantKey
				, ROW_NUMBER() OVER(
					PARTITION BY prd.matchid
					ORDER BY ProviderResultDetailId DESC
				) AS RowIdx
				
			FROM @tblMatchInQueue q
				INNER JOIN dbo.ProviderResultDetail prd WITH(NOLOCK)
				ON q.matchid = prd.matchID
				INNER JOIN dbo.match m WITH(NOLOCK) 
				ON q.matchid = m.matchid
				INNER JOIN dbo.league l WITH(NOLOCK) 
				ON m.leagueid = l.leagueid
				
			WHERE prd.TypeId IN (101, 102)
				AND prd.SourceID = 100 --#86964
				AND m.sporttype = 1
				AND m.eventstatus = 'running' 				
				AND 2 & ISNULL(m.AutoSetting,l.AutoSetting) = 2
				AND m.SettlementStatus & 87 = 0 ----bit 1,2,3,5,7
		) AS t
		WHERE RowIdx IN (1, 2)
	)

	UPDATE d
	SET HomeValue			= temp.HomeValue
		, AwayValue			= temp.AwayValue
		, InstantStatusId	= 1 --temp.StatusId
		, CalculationType	= temp.CalculationType
		, InstantKey		= temp.InstantKey
		--, InstantScoreDiff	= CASE WHEN (chk.matchID > 0 AND  (temp.HomeValue < chk.HomeValue OR temp.AwayValue < chk.AwayValue) ) THEN 1 ELSE 0 END
		, InstantScoreDiff	= CASE WHEN (chk.matchID > 0 AND  (CAST(ISNULL(temp.HomeValue, 0) AS INT)) < (CAST(ISNULL(chk.HomeValue, 0) AS INT)) OR (CAST(ISNULL(temp.AwayValue, 0) AS INT)) < (CAST(ISNULL(chk.AwayValue, 0) AS INT))) THEN 1 ELSE 0 END
	FROM @tblMatchInQueue d
		INNER JOIN InstMatchConfirm AS temp		
			ON d.matchID = temp.matchID
		LEFT JOIN InstMatchConfirm AS chk 
			ON temp.matchID = chk.matchID AND chk.RowIdx = 2
		LEFT JOIN dbo.AutoPayoutResult aps WITH(NOLOCK)
			ON temp.matchid = aps.matchID
			AND temp.CalculationType = aps.CalculationType
			AND temp.HomeValue 	= aps.HomeValue
			AND temp.AwayValue 	= aps.AwayValue
			
	WHERE temp.RowIdx = 1
		AND (
			aps.StatusId IS NULL --not confirm yet
			OR (aps.StatusId = 3 --FAILED to re-confirm
			    
						 --#86964
						 AND (NOT EXISTS (SELECT 1 FROM dbo.AutoPayoutResult a WITH(NOLOCK)  --SUCCESSS by Others (Auto/Manual)
									   WHERE a.matchid			  = aps.matchID
									   AND a.CalculationType	  = aps.CalculationType
									   AND a.HomeValue		  = aps.HomeValue
									   AND a.AwayValue		  = aps.AwayValue
									   AND a.StatusId		  = 2)
							 
							 OR EXISTS (SELECT 1 FROM (SELECT TOP 2 MatchID, ModifiedDate, StatusID, -- Not Calculate yet
												    ROW_NUMBER() OVER( PARTITION BY aps.matchid ORDER BY ModifiedDate DESC) AS RowIdx
												  FROM dbo.AutoPayoutResult aps WITH(NOLOCK)
												  WHERE aps.matchid		   = temp.matchID
												    AND aps.CalculationType = temp.CalculationType
												    AND aps.HomeValue	   = temp.HomeValue
												    AND aps.AwayValue	   = temp.AwayValue
									  ) AS T1
									  LEFT JOIN (SELECT TOP 2 MatchID, ModifiedDate, StatusID,
											     ROW_NUMBER() OVER( PARTITION BY aps.matchid ORDER BY ModifiedDate DESC) AS RowIdx
											   FROM dbo.AutoPayoutResult aps WITH(NOLOCK)
											   WHERE aps.MatchID		 = temp.MatchID
												AND aps.CalculationType	 = temp.CalculationType
												AND aps.HomeValue		 = temp.HomeValue
												AND aps.AwayValue		 = temp.AwayValue
										  ) AS T2 ON T1.MatchID= T2.MatchID AND T2.RowIdx = 2
										  WHERE T1.RowIdx = 1
										  AND (T1.StatusID <> 2 AND T1.ModifiedDate > T2.ModifiedDate) --last update still calculate failed
									  )
							 )
					  )--#86964

			OR (aps.StatusId = 2 AND temp.IsConfirmed = 0) --abnormal case -> re-calculate
		)
		
	--update instant match status info
	;WITH InstMatchInProgress AS (
		SELECT m.MatchId
			, aps.HomeValue
			, aps.AwayValue
			, 2 AS InstantStatusId --has confirmed
			, aps.CalculationType
		FROM @tblMatchInQueue m
			INNER JOIN dbo.AutoPayoutResult aps WITH(NOLOCK)
			ON m.matchid = aps.matchID
			
		WHERE aps.StatusId IN (1) --waiting|calculating
			AND aps.CalculationType IN (101, 102)	
	)
	UPDATE q
	SET HomeValue 			= im.HomeValue
		,AwayValue			= im.AwayValue
		,InstantStatusId	= im.InstantStatusId
		,CalculationType	= im.CalculationType
	FROM @tblMatchInQueue q	
		INNER JOIN InstMatchInProgress im
		ON q.MatchId = im.matchid
	
	UPDATE q 
		SET InstantHomeScoreBefore = aps.HomeScore
			,InstantAwayScoreBefore = aps.AwayScore
			,InstantGoalRecordBefore = aps.GoalRecord
	FROM	@tblMatchInQueue q
		CROSS APPLY (
			SELECT	TOP 1 CAST(aps.HomeValue AS TINYINT) AS HomeScore
					,CAST(aps.AwayValue AS TINYINT) AS AwayScore
					,ISNULL(gc.GoalRecord, '') AS GoalRecord
			FROM	dbo.AutoPayoutResult aps WITH (NOLOCK)
				OUTER APPLY (
					SELECT TOP 1 HomeValue AS GoalRecord
					FROM dbo.ProviderResultDetail ps WITH (NOLOCK)
					WHERE matchid 			= q.matchid
						AND TypeId 			= 103 -- FGNG
						AND IsConfirmed		= 1 -- completed
					ORDER BY ProviderResultDetailId DESC
				) AS gc
			WHERE	q.matchid = aps.matchid
					AND q.CalculationType = aps.CalculationType
					AND aps.StatusId = 2 -- completed
			ORDER BY ModifiedDate DESC
		) aps
		
	-- return output result
	SELECT	m.matchid
			,m.leagueid
			,m.hthomescore AS HalfTimeHomeScore
			,m.htawayscore AS HalfTimeAwayScore
			,ISNULL(mr.calculate,0) AS IsCalculated
			,ISNULL(CASE WHEN r.ResultStatusID = 5 THEN 1 ELSE 0 END,0) AS IsFTCalculated
			,ISNULL(mr.multiple,0) AS IsMultiCaled
			,ISNULL(mr.refund,0) AS IsRefund
			,ISNULL(mr.calrefund,0) AS IsCalRefund
			,m.homeid
			,m.awayid
			,m.matchcode
			,m.finalhomescore
			,m.finalawayscore
			,m.betstatus
			,m.eventstatus 
			,ISNULL(mr.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
			,m.goalrecord
			,ISNULL(mr.IsHTCal,0) AS IsHalfTimeCal
			,ISNULL(m.SettlementStatus,0) AS SettlementStatus
			,q.SingleStatus AS IsCalculatingSingle
			,q.HTStatus
			,q.FTStatus
			,CASE mr.ConfirmHT WHEN 0 THEN '' ELSE (SELECT username FROM dbo.custInfo ci (NOLOCK) WHERE ci.custid = mr.ConfirmHT) END suspenderHalfTime 
			,CASE mr.ConfirmFT WHEN 0 THEN '' ELSE (SELECT username FROM dbo.custInfo ci (NOLOCK) WHERE ci.custid = mr.ConfirmFT) END suspenderFullTime
			,CASE 
				WHEN m.AutoSetting IS NULL THEN ISNULL(l.AutoSetting, 0)
				ELSE ISNULL(m.AutoSetting, 0) 
			END AS AutoSetting
			,mr.IsHTCal

			/*Instant match info*/
			, m.livehomescore
			, m.liveawayscore
			, mr.IsHT
			, mr.LivePeriod
			, q.HomeValue
			, q.AwayValue
			, q.InstantStatusId
			, q.CalculationType
			, q.InstantKey
			, q.InstantScoreDiff
			,ISNULL(q.GoalRecordFTResultStatusId,0) AS GoalRecordFTResultStatusId
			,ISNULL(q.FTFGNGResultStatusId,0) AS FTFGNGResultStatusId
			,ISNULL(q.FTLGResultStatusId,0) AS FTLGResultStatusId
			,ISNULL(q.HTFGNGResultStatusId,0) AS HTFGNGResultStatusId
			,ISNULL(q.HTLGResultStatusId,0) AS HTLGResultStatusId
			,m.EventStatusReason
			,ISNULL(l.AutoSetting, 0) AS AutoSettingForLeague
			,ISNULL(ss.WaitingTime, 120) AS InstantWaitingTime
			,ISNULL(ssDirect.WaitingTime, 1) AS DirectWaitingTime
			,ISNULL(q.InstantHomeScoreBefore,'') AS InstantHomeScoreBefore
			,ISNULL(q.InstantAwayScoreBefore,'') AS InstantAwayScoreBefore
			,ISNULL(q.InstantGoalRecordBefore,'') AS InstantGoalRecordBefore
			
	FROM	@tblMatchInQueue q
		INNER JOIN match m WITH(NOLOCK)
			ON	q.MatchId = m.matchid
		INNER JOIN match_remark mr WITH(NOLOCK) 
			ON	m.matchid = mr.matchid
		INNER JOIN dbo.league l WITH(NOLOCK) 
			ON	m.leagueid = l.leagueid		
		LEFT JOIN dbo.ResultDetail r WITH (NOLOCK)
			ON	m.matchid = r.MatchId
				AND r.ResourceId = '00'
		OUTER APPLY (
			SELECT TOP 1 ss.WaitingTime
			FROM	dbo.SettlementSetting ss WITH (NOLOCK)
			WHERE	ss.LeagueId = l.leagueid
					AND AutoType = 2
		)ss
		OUTER APPLY (
			SELECT TOP 1 ss.WaitingTime
			FROM	dbo.SettlementSetting ss WITH (NOLOCK)
			WHERE	ss.LeagueId = l.leagueid
					AND AutoType = 5
		)ssDirect
		
END
GO