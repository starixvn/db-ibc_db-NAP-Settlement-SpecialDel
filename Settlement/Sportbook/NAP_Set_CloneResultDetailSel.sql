/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_Set_CloneResultDetailSel
	@MatchId INT
	,@SportType SMALLINT
AS
/*
    Created by: 20200831@Louisa
    Task: Copy Result from DBPRO to SIT [Redmine:#140407]
    DB: DBPRO/BODB02  
    
    Revisions:            
		- 20200831@Louisa: Copy Result from DBPRO to SIT [Redmine:#140407]

	Param's explanation:
		@MatchId: MatchId on PRODUCTION
		
*/
BEGIN
	SET NOCOUNT ON

	IF @SportType =  43
	BEGIN
		SELECT 
			r.ResourceId
			,r.HomeValue
			,r.AwayValue
			,r.ResultStatusID
			,r.SettlementStatusID
			,r.CreateDate
			,r.LastModifyDate
			,r.CreateBy
			,r.LastModifyBy
			,r.OtherInfo
		FROM ResultDetailES r
		WHERE r.MatchID  = @MatchId

		---ExternalResult
		SELECT	
			er.MatchId3rd
			,er.SourceId
			,er.ResourceId
			,er.HomeValue
			,er.AwayValue
			,er.OtherInfo
			,er.CreateDate
			,er.LastModifyDate
			,er.CreateBy
			,er.LastModifyBy	
		FROM	ProviderExternalResultDetailES er
		WHERE er.MatchID = @MatchId
	END
END
GO