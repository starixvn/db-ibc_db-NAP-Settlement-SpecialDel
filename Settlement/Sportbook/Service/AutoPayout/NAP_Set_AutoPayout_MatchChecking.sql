/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_MatchChecking] 
	@matchid INT
AS
/*
    Created by: 20190507@Sol
    Task: Checking FGLG bettypes exist in match 
    DB: DBTXN/BODB02 
    Original: 
    
    Revisions:            
		- 20190507@Sol: Auto payout phase 3 - Checking FGLG bettypes exist in match - [Redmine:#116073]
		- 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
*/
BEGIN
    SET NOCOUNT ON
    
	DECLARE @IsCentral BIT = 0
	DECLARE @tmpGoalRecordBettypes TABLE (bettype SMALLINT, GroupId TINYINT, isFGLG BIT)
    
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

    INSERT INTO @tmpGoalRecordBettypes (bettype, GroupId,isFGLG)
	SELECT	BetType, GroupId,isFGLG
	FROM	dbo.[f_Set_GetGroupBettypes]()
	WHERE	IsUsedGoalRecordValue  = 1
	
	;WITH cteBettypes
	AS
	(
		SELECT	b.bettype
				,MAX(CASE WHEN f.isFGLG = 1 AND f.GroupId IN (2,4)  THEN 1 ELSE 0 END) AS ExistFGLG
				,MAX(CASE WHEN f.isFGLG = 1 AND f.GroupId IN (1,3)  THEN 1 ELSE 0 END) AS ExistHTFGLG
				,MAX(CASE WHEN f.isFGLG = 1 THEN 1 ELSE 0 END ) AS ExistFGNG
				,MAX(f.GroupId) AS GroupId
		FROM	dbo.bettrans b WITH(NOLOCK)
				INNER JOIN @tmpGoalRecordBettypes f
					ON	b.bettype = f.BetType
		WHERE	b.matchid = @matchid
				AND b.statusID NOT IN (101, 102)
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		GROUP BY b.bettype

		UNION ALL

		SELECT	bm.bettype
				,MAX(CASE WHEN f.isFGLG = 1 AND f.GroupId IN (2,4)  THEN 1 ELSE 0 END) AS ExistFGLG
				,MAX(CASE WHEN f.isFGLG = 1 AND f.GroupId IN (1,3)  THEN 1 ELSE 0 END) AS ExistHTFGLG
				,MAX(CASE WHEN f.isFGLG = 1 THEN 1 ELSE 0 END ) AS ExistFGNG
				,MAX(f.GroupId) AS GroupId
		FROM	dbo.bettransm bm WITH(NOLOCK)
				INNER JOIN @tmpGoalRecordBettypes f
					ON	bm.bettype = f.BetType
		WHERE	bm.matchid = @matchid
				AND bm.statusID NOT IN (101, 102)
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
		GROUP BY bm.bettype
	)
	SELECT  ISNULL(MAX(CASE WHEN ExistFGLG = 1 THEN 1 ELSE 0 END),0) AS IsExistFGLG
			, ISNULL(MAX(CASE WHEN ExistHTFGLG = 1 THEN 1 ELSE 0 END),0) AS IsExistHTFGLG
			, ISNULL(MAX(CASE WHEN GroupId IN (1,3) THEN 1 ELSE 0 END), 0) AS IsEnabledGoalRecordHT
			, ISNULL(MAX(CASE WHEN GroupId IN (2,4) THEN 1 ELSE 0 END), 0) AS IsEnabledGoalRecordFT
			, ISNULL(MAX(CASE WHEN ExistFGNG = 1 THEN 1 ELSE 0 END),0) AS IsExistFGNG
	FROM	cteBettypes

END
GO