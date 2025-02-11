/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_MatchSelDetail]
	@MatchId INT
AS
/*
	Created: Kathy
	Date: 20170828
	Task : get match info
	DB: DBPRO/bodb02

	Revisions:
		- 20170828@Kathy: create new SP [Redmine:#82220]
		- 20181002@Kathy: get eventstatus & betstatus [Redmine:#102028]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		- 20220512@Louisa: Auto settle for Badminton [Redmine:#171676]
		- 20220613@Louisa: Auto Payout for matches TOTAL CORNER & TOTAL GOAL [Redmine:#171261]
		- 20220706@Louisa: Fix cannot get resultdetail Badminton [Redmine:#171261]
		- 20221213@Kathy: Upgrade Auto Payout for Badminton & Volleyball [Redmine:#181458]
		- 20250113@Hughie: Apply SOP for Soccer [Redmine:#216004]

	Parameters Explanation:    
	
	
*/
BEGIN
	SET NOCOUNT ON
	SET NOCOUNT ON

	DECLARE @sporttype SMALLINT, @ParentId INT, @MainType TINYINT
	
	DECLARE  @tmpMatch_Info TABLE 
	(  matchid INT, ParentId INT, sporttype SMALLINT
		, eventstatus NVARCHAR(100), betstatus NVARCHAR(100), SettlementStatus TINYINT, EventStatusReason TINYINT
		, AutoSetting TINYINT, MainType TINYINT, ChildMatchType TINYINT 
	)
	
	DECLARE  @tmpResult_Info TABLE (matchid INT, ResourceId VARCHAR(20), HomeValue VARCHAR(20), AwayValue VARCHAR(20), ResultStatusId TINYINT, SettlementStatusId TINYINT, ResultSetting TINYINT)

	--get match info
	INSERT INTO @tmpMatch_Info ( matchid, ParentId, sporttype, eventstatus, betstatus, SettlementStatus, EventStatusReason, AutoSetting, MainType, ChildMatchType)
	SELECT 	m.matchid, m.ParentId, m.sporttype	,m.eventstatus	,m.betstatus	,m.SettlementStatus	,m.EventStatusReason, ISNULL(m.AutoSetting, l.AutoSetting) AS AutoSetting, mr.MainType, m.ChildMatchType
	FROM	dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.match_remark mr WITH(NOLOCK)
			ON m.matchid = mr.matchid
		INNER JOIN dbo.League l WITH(NOLOCK) 
			ON m.leagueid = l.leagueid
	WHERE	m.matchid = @matchid

	SELECT @sporttype = sporttype 
		, @ParentId = ParentId
		,@MainType = MainType
	FROM @tmpMatch_Info

	IF @sporttype = 1
	BEGIN
		INSERT INTO @tmpMatch_Info (matchid, eventstatus, betstatus, SettlementStatus, EventStatusReason, AutoSetting, ChildMatchType)
		SELECT matchid, eventstatus, betstatus, SettlementStatus, EventStatusReason, AutoSetting, ChildMatchType
		FROM dbo.match m WITH(NOLOCK)
		WHERE m.matchid =  @ParentId
		OR (m.ParentID IS NOT NULL AND m.ParentID = @ParentId AND ISNULL(m.ChildMatchType,0) = 204)

		INSERT INTO @tmpResult_Info (matchid, ResourceId, HomeValue, AwayValue, ResultStatusId, SettlementStatusId, ResultSetting  )
		SELECT r.matchid, r.ResourceId, r.HomeValue, r.AwayValue, r.ResultStatusId, r.SettlementStatusID, r.ResultSetting
		FROM dbo.ResultDetail r WITH(NOLOCK)
			INNER JOIN @tmpMatch_Info m ON m.matchid = r.MatchId
		WHERE m.matchid = @MatchId
			AND r.ResourceId IN ( '01', '00')
	END

	SELECT  matchid, eventstatus, betstatus, SettlementStatus, EventStatusReason, AutoSetting
	FROM @tmpMatch_Info
	WHERE matchid = @MatchId

	SELECT r.MatchId, m.ChildMatchType, r.ResourceId, r.HomeValue, r.AwayValue, r.ResultStatusID, r.SettlementStatusId, r.ResultSetting
	FROM @tmpMatch_Info m
		INNER JOIN @tmpResult_Info r 
			ON m.matchid = r.matchid


END

GO