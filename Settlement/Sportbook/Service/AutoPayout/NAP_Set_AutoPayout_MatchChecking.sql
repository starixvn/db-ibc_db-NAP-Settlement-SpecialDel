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
		- 20190507@Sol: Checking FGLG bettypes exist in match - [Redmine:#106901]
*/
BEGIN
    SET NOCOUNT ON
    	
	DECLARE @tmpGoalRecordBettypes TABLE (bettype SMALLINT, GroupId TINYINT, isFGLG BIT)
    
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
				,MAX(f.GroupId) AS GroupId
		FROM	dbo.bettrans b WITH(NOLOCK)
				INNER JOIN @tmpGoalRecordBettypes f
					ON	b.bettype = f.BetType
		WHERE	b.matchid = @matchid
				AND b.statusID NOT IN (101, 102)
		GROUP BY b.bettype

		UNION ALL

		SELECT	bm.bettype
				,MAX(CASE WHEN f.isFGLG = 1 AND f.GroupId IN (2,4)  THEN 1 ELSE 0 END) AS ExistFGLG
				,MAX(CASE WHEN f.isFGLG = 1 AND f.GroupId IN (1,3)  THEN 1 ELSE 0 END) AS ExistHTFGLG
				,MAX(f.GroupId) AS GroupId
		FROM	dbo.bettransm bm WITH(NOLOCK)
				INNER JOIN @tmpGoalRecordBettypes f
					ON	bm.bettype = f.BetType
		WHERE	bm.matchid = @matchid
				AND bm.statusID NOT IN (101, 102)
		GROUP BY bm.bettype
	)
	SELECT  ISNULL(MAX(CASE WHEN ExistFGLG = 1 THEN 1 ELSE 0 END),0) AS IsExistFGLG
			, ISNULL(MAX(CASE WHEN ExistHTFGLG = 1 THEN 1 ELSE 0 END),0) AS IsExistHTFGLG
			, ISNULL(MAX(CASE WHEN GroupId IN (1,3) THEN 1 ELSE 0 END), 0) AS IsEnabledGoalRecordHT
			, ISNULL(MAX(CASE WHEN GroupId IN (2,4) THEN 1 ELSE 0 END), 0) AS IsEnabledGoalRecordFT
	FROM	cteBettypes

END
