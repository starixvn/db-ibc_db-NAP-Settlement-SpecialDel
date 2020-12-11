/*<info serverAlias="DBPRO-bodb02 " executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderExternalResultDetailLatestInfoSel]
	@MatchId	INT
AS
/*
    Created by: 20201202@Louisa
    Task: Integrate with SBO [Redmine:#146239]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20201202@Louisa: SBO Result for 8 sports:3,4,6,8,9,18,24,25  [Redmine:#146239]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT = 0

	SELECT @SportType = m.SportType FROM dbo.Match m WITH(NOLOCK) WHERE m.MatchID = @MatchId
	
    ---------------------------------------------------------------------------------------------
	IF @SportType IN ( 5, 9 )
	BEGIN
		;WITH  cteLatestOS	AS
		(
			SELECT	ROW_NUMBER() OVER (PARTITION BY ex.ResourceId ORDER BY ex.CreateDate DESC) AS rn
					,ex.ResourceId
					,ex.HomeValue
					,ex.AwayValue
			FROM	dbo.ProviderExternalResultDetailOS ex WITH(NOLOCK)
			WHERE ex.MatchID = @MatchId
				AND  ex.SourceId  = CASE 
									WHEN @SportType = 5 THEN 25 --LSport
									ELSE 1 END ---SBO
		)		
		SELECT  ResourceId 
				,HomeValue 
				,AwayValue 
		FROM	cteLatestOS
		WHERE	rn = 1
	END

	ELSE  ---- Currently, just have data for SportType IN (3, 4, 6, 8, 18, 24, 25)
	BEGIN
		;WITH  cteLatestSports AS
			(
				SELECT	ROW_NUMBER() OVER (PARTITION BY ex.ResourceId ORDER BY ex.CreateDate DESC) AS rn
						,ex.ResourceId
						,ex.HomeValue
						,ex.AwayValue
				FROM	dbo.ProviderExternalResultDetail ex WITH(NOLOCK)
				WHERE ex.MatchID = @MatchId
					AND  ex.SourceId  = 1
			)
		SELECT	ResourceId 
				,HomeValue 
				,AwayValue 
		FROM	cteLatestSports
		WHERE	rn = 1
	END

END