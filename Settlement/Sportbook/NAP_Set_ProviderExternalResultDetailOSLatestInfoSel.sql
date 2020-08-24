/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_Set_ProviderExternalResultDetailOSLatestInfoSel
	@MatchId INT
AS
/*
    Created by: 20200824@Louisa
    Task: get latest LSports result [Redmine:#139979]
    DB: DBPRO/BODB02
    
    Revisions:            
		- 20200824@Louisa: get latest LSports result [Redmine:#139979]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT


	SET @SportType = 5

	;WITH cteLatestId
	AS(
		SELECT	ROW_NUMBER() OVER (PARTITION BY p.ResourceId ORDER BY p.CreateDate DESC) AS rn
				,p.ResourceId
				,p.HomeValue
				,p.AwayValue
		FROM	dbo.ProviderExternalResultDetailOS p WITH(NOLOCK)
		WHERE	p.MatchId = @MatchId
			AND SourceId  =25
	)
	SELECT ResourceId
		  ,HomeValue
		  ,AwayValue
	FROM	cteLatestId
	WHERE	rn = 1

END
GO



