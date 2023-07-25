/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ResultConfirmRefundSel
	 @MatchId		INT 
	,@SourceId		SMALLINT	= 99
AS
/*
    Created by: 20230515@Aries
    Task: Apply Settle Determined for Basketball [Redmine:#175202]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20230515@Aries: Apply Settle Determined for Basketball [Redmine:#175202]
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT	 p.MatchId
			,p.ResourceId
			,p.HomeValue
			,p.AwayValue
			,p.SourceID
			,p.CreateDate
			,p.CreateBy
			,p.LastModifyDate
			,p.LastModifyBy
	FROM	dbo.ProviderExternalResultDetail p WITH(NOLOCK)
	WHERE	p.MatchId = @MatchId 
		AND p.SourceId = @SourceId
			
END
GO