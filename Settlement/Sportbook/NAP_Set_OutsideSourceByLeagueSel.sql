/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[NAP_Set_OutsideSourceByLeagueSel]
(
	@LeagueId INT
)
AS
/*
    Created by: 20200805@Louisa
    Task: get TOP 4 OutsideSource by LeagueId  [Redmine:#138656]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20200805@Louisa: get TOP 4 OutsideSource by LeagueId  [Redmine:#138656]
	
	Param's Explanation:
		PGId = 0: create new mapping for OutsideSource 1001
		Return 2 datasets: the first for select list, the second is TOP 4 OutsideSource by LeagueId (Initial = Screenshot 1001)
		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @GameType TINYINT

	SELECT @GameType =  l.OverTimeSession 
						FROM League l  WITH(NOLOCK)
						WHERE l.LeagueId = @LeagueId

	CREATE TABLE #GameTypeMapping 
	( 
		 PGId INT
		,SourceId SMALLINT
		,SourceName VARCHAR(50)
		,Remark NVARCHAR(1000) 
	)

	INSERT INTO #GameTypeMapping  (PGId ,SourceId, SourceName, Remark)
	SELECT
		pgm.PGId
		,pi.SourceId
		,pi.SourceName
		,pi.Remark
	FROM ProviderInfo pi WITH(NOLOCK)
		CROSS APPLY	(
					SELECT 	pgm.PGId FROM ProviderGameTypeMapping pgm WITH(NOLOCK)
					WHERE pgm.GameType = @GameType 
						AND pi.SourceId = pgm.SourceId 
						AND pgm.isActive =1 
					) pgm
	WHERE pi.SourceID > 1000
		AND pi.isActive  =1
  
	IF NOT EXISTS (SELECT PGId FROM #GameTypeMapping WHERE SourceId = 1001 )
		BEGIN
			INSERT INTO	 #GameTypeMapping (PGId , SourceId, SourceName, Remark) SELECT	0 , 1001, 'Screenshot', 'n/a' 
		END

	SELECT DISTINCT PGId, SourceName, Remark 
	FROM #GameTypeMapping
	WHERE  SourceId <> 1001

	SELECT
		 ISNULL(plmo.PGId,GM.PGId) AS PGId
		,gm.SourceName
		,gm.Remark
		,ISNULL( OrderNo,1) OrderNo 
	FROM #GameTypeMapping gm 
		OUTER APPLY	( 
					SELECT plmo.PGId,  plmo.OrderNo FROM ProviderLeagueMappingOutsideSource plmo  WITH(NOLOCK)
					WHERE plmo.PGId  = gm.PGId AND plmo.LeagueId  = @LeagueId
					) plmo
	WHERE plmo.PGId IS NOT NULL  OR gm.SourceId =  1001
		ORDER BY OrderNo

	DROP TABLE #GameTypeMapping	

END
GO

