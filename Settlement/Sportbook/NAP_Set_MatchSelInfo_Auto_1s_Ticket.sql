/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelInfo_Auto_1s_Ticket]
	@MatchID		INT
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Initial  [Redmine:#175251]

	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON 
	
	DECLARE @IsExistFGLG 		BIT = 0
			,@IsExistHTFGLG  	BIT = 0
			,@IsCentral			BIT
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
		
	CREATE TABLE #BettypeFGLG  (bettype SMALLINT, GroupID SMALLINT)
	INSERT INTO #BettypeFGLG (bettype,GroupID)
	SELECT BetType,GroupID
	FROM dbo.f_Set_GetGroupBettypes()
	WHERE IsFGLG = 1
	
	IF EXISTS (SELECT TOP 1 1 
				FROM dbo.bettrans b WITH (NOLOCK) 
				WHERE matchid = @matchId AND StatusId NOT IN (101, 102) 
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND EXISTS (SELECT 1 FROM #BettypeFGLG fglg WITH (NOLOCK) WHERE fglg.bettype = b.bettype AND fglg.GroupID IN (2,4))
			)
		SET @IsExistFGLG = 1
	ELSE IF EXISTS (SELECT TOP 1 1 
					FROM dbo.bettransm bm WITH (NOLOCK) 
					WHERE matchid = @matchId AND StatusId NOT IN (101, 102) 
							AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
							AND EXISTS (SELECT 1 FROM #BettypeFGLG fglg WITH (NOLOCK) WHERE fglg.bettype = bm.bettype AND fglg.GroupID IN (2,4))
					)
		SET @IsExistFGLG = 1
		
	IF EXISTS (SELECT TOP 1 1 
				FROM dbo.bettrans b WITH (NOLOCK) 
				WHERE matchid = @matchId AND StatusId NOT IN (101, 102) 
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND EXISTS (SELECT 1 FROM #BettypeFGLG fglg WITH (NOLOCK) WHERE fglg.bettype = b.bettype AND fglg.GroupID IN (1,3))
				)
		SET @IsExistHTFGLG = 1
	ELSE IF EXISTS (SELECT TOP 1 1 
					FROM dbo.bettransm bm WITH (NOLOCK) 
					WHERE matchid = @matchId AND StatusId NOT IN (101, 102) 
						AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
						AND EXISTS (SELECT 1 FROM #BettypeFGLG fglg WITH (NOLOCK) WHERE fglg.bettype = bm.bettype AND fglg.GroupID IN (1,3))
					)
		SET @IsExistHTFGLG = 1
	
	SELECT	 @MatchID		AS MatchID
			,@IsExistFgLg	AS IsExistFgLg
            ,@IsExistHtFgLg AS IsExistHtFgLg
	
	DROP TABLE #BettypeFGLG

END
GO