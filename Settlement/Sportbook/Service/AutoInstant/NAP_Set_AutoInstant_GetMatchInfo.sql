/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoInstant_GetMatchInfo]
	 @MatchId		INT	
	, @InstantKey		INT	
	, @HomeScore		VARCHAR(50)
	, @AwayScore		VARCHAR(50)

AS
/*
	Creator: 20180115@Benjamin
	Task: Get Match information score for AutoInstant Verification.
	DB: DBPRO/bodb02
	Revisions:
		- 20180115@Benjamin: Implement for first verion [Redmine:#86964]
		- 20180801@Kaden: Verify calculateHT before calculating FT [Redmine:#99247]
		- 20181205@Vicky: Add New Undecided Option for MTD team [Redmine:#104948]
		- 20220520@Louisa: If AutoSetting on Match IS NULL, get AutoSetting on Leagues [Redmine:#172907]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:
			@MatchId:	   MatchID need to compare Score
			@HomeScore:   HomeScore in Pool and in Processing
			@AwayScore:   AwayScore in Pool and in Processing
	 
	Comparing Info:
			AutoSetting: 0-OFF/2-On Instant/3-On Autopayout and Instant 
			SettlementStatus: BIT: 1: Pending, 2: Undecided, 3: undersettlement, 4: SystemSettlement, 5: MTDHold
			CurrentHomeScore: In Pool HomeScore
			CurrentAwayScore: In Pool AwayScore
			HTHomescore: HT Home Score
			HTAwayscore: HT Away Score
			GoalRecord: GoalRecord
			IsExistFGNG: FGNG
			IsExistHTFGNG: HTFGNG
			PreviousHomeScore: PreviousHomeScore
			PreviousAwayScore: PreviousAwayScore	
			IsCalculatedHT: 0-NotCalculatedHT/1-IsCalculatedHT		
			IsCalculatedFT: 0-NotCalculatedFT/1-IsCalculatedFT
			IsInstCalculated: 0- Inst not Calculated/1- Inst Calculated
*/
BEGIN
	
	SET NOCOUNT ON

	CREATE TABLE #Match_Info (MatchID			INT
					   , AutoSetting			INT
					   , SettlementStatus		TINYINT
					   , IsCalculatedHT			BIT
					   , TypeID					INT
					   , CurrentHomeScore		VARCHAR(50)
					   , CurrentAwayScore		VARCHAR(50)
					   , HTHomescore			INT
					   , HTAwayscore			INT
					   , InstantKey				INT
					   , PreviousHomeScore		VARCHAR(50)
					   , PreviousAwayScore		VARCHAR(50)
					   , GoalRecord				VARCHAR(50)
					   , betstatus				NVARCHAR(50)
					  )

	CREATE TABLE #FGLG (MatchID					 INT
				  , IsExistFGNG				 BIT
				  , IsExistHTFGNG				 BIT)

	CREATE TABLE #Match_Status (MatchID				 INT
						, IsCalculatedFT		 BIT
						 , IsInstCalculated	 BIT)

	   --Match Info
	   INSERT INTO #Match_Info (MatchID, AutoSetting, SettlementStatus, IsCalculatedHT, TypeID, CurrentHomeScore, CurrentAwayScore, HTHomescore, HTAwayscore, PreviousHomeScore, PreviousAwayScore, InstantKey, GoalRecord, betstatus)
	   SELECT  @MatchId
			, ISNULL(m.AutoSetting, l.AutoSetting)
			, m.SettlementStatus
			, mr.IsHTCal AS IsCalculatedHT
			, d.TypeID
			, d.HomeValue AS CurrentHomeScore
			, d.AwayValue AS CurrentAwayScore
			, ISNULL(m.HTHomescore, 0) AS HTHomescore
			, ISNULL(m.HTAwayscore, 0) AS HTAwayscore
			, ISNULL(p.HomeValue, 0) AS PreviousHomeScore
			, ISNULL(p.AwayValue, 0) AS PreviousAwayScore
			, p.ProviderResultDetailID AS InstantKey
			, ISNULL(pr.HomeValue, '') AS GoalRecord
			, m.betstatus
	   FROM dbo.Match m WITH (NOLOCK)
		   INNER JOIN dbo.Match_Remark mr WITH (NOLOCK)
				ON m.MatchID = mr.MatchID
		   INNER JOIN dbo.League l WITH(NOLOCK) 
				ON m.leagueid = l.leagueid
		   INNER JOIN (SELECT ProviderResultDetailID, MatchID, SourceID, TypeID, HomeValue, AwayValue, CreatedDate  
					   FROM dbo.ProviderResultDetail  WITH (NOLOCK)
					  WHERE ProviderResultDetailID = @InstantKey
						AND HomeValue = @HomeScore 
						AND AwayValue = @AwayScore) d
		   ON m.MatchID = d.MatchID

		   LEFT JOIN (SELECT TOP 1 MatchId, ProviderResultDetailID, HomeValue, AwayValue
					FROM dbo.ProviderResultDetail pr WITH(NOLOCK)
					WHERE pr.TypeID IN (101,102)
					 AND pr.SourceID = 100
					 AND pr.IsConfirmed =1  --Processed
					 AND pr.MatchID = @MatchID
					 AND (EXISTS (SELECT 1
							   FROM dbo.AutoPayoutResult ap WITH(NOLOCK)
							   WHERE ap.MatchID	  = pr.MatchID
								AND ap.HomeValue = pr.HomeValue
								AND ap.AwayValue = pr.AwayValue
								AND ap.StatusID  = 2)
					 OR EXISTS(SELECT 1
							 FROM dbo.ResultDetail r WITH(NOLOCK)
							 WHERE r.MatchID = pr.MatchID
							 AND r.HomeValue = pr.HomeValue
							 AND r.AwayValue = pr.AwayValue
							 AND r.ResourceID IN ('01','00')
							 AND r.ResultStatusID IN (2,5)
							 AND r.SettlementStatusID = 4))
							 
					 ORDER BY ProviderResultDetailID DESC) p
			ON m.MatchID = p.MatchId

		  LEFT JOIN (SELECT MatchID, HomeValue, AwayValue
					FROM dbo.ProviderResultDetail WITH (NOLOCK)
					WHERE MatchID = @MatchID
					 AND TypeId = 103) pr
			ON m.MatchID = pr.MatchID AND pr.AwayValue = @InstantKey
			 
	   WHERE m.sporttype = 1
		AND m.MatchID = @MatchID
		--Failure when compare/verify
			AND NOT EXISTS (SELECT 1
					 FROM dbo.AutoPayoutResult ap WITH(NOLOCK)
					 WHERE ap.MatchID = d.MatchID
					   AND ap.HomeValue = d.HomeValue
					   AND ap.AwayValue = d.AwayValue
					   AND ap.StatusID = 3
					   AND ap.SourceID IN (100, 5) 
					   AND ap.ModifiedDate > d.CreatedDate)

	   --Calculated
	   INSERT INTO #Match_Status (MatchID, IsCalculatedFT, IsInstCalculated)
	   SELECT @MatchID
		   , MAX(CASE WHEN r.SettlementStatusID = 4 THEN 1 ELSE 0 END) AS IsCalculatedFT
		   , MAX(CASE WHEN aps.StatusID IN (1,2) THEN 1 ELSE 0 END) AS IsInstCalculated  
	   FROM #Match_Info m
		LEFT JOIN dbo.ResultDetail r WITH(NOLOCK)
		  ON m.MatchID = r.MatchID 
		   AND r.ResourceID = '00' --FT Calculate
		   AND r.ResultStatusID IN (2,5)	   --Auto/Manual  

		LEFT JOIN (SELECT TOP 1 a.MatchID, a.StatusID, a.HomeValue, a.AwayValue, a.CalculationType
				FROM dbo.AutoPayoutResult a WITH(NOLOCK) 
				WHERE MatchID = @MatchID 
				  AND a.CalculationType IN (101,102)  --Instant
				  AND a.SourceID IN (100, 5) --Manual/Auto
				  AND a.StatusID IN (1,2) --Calculated
				  ORDER BY a.ModifiedDate DESC
				) aps ON m.MatchID = aps.MatchID AND aps.HomeValue = m.CurrentHomeScore AND aps.AwayValue = m.CurrentAwayScore AND aps.CalculationType = m.TypeID

	SELECT m.AutoSetting
		, m.SettlementStatus
		, m.TypeID
		, HTHomescore		
		, HTAwayscore
		, m.PreviousHomeScore
		, m.PreviousAwayScore
		, m.InstantKey 
		, m.GoalRecord
		, m.IsCalculatedHT			
		, CAST(ISNULL(n.IsCalculatedFT, 0) AS BIT) AS IsCalculatedFT
		, CAST(ISNULL(n.IsInstCalculated, 0) AS BIT) AS IsInstCalculated
		, m.betstatus
	FROM #Match_Info m
	LEFT JOIN #Match_Status n ON m.MatchID = n.MatchID


	DROP TABLE #match_info
	DROP TABLE #Match_Status

END
GO