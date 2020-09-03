/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_CloneResultDetailSel
	@MatchId INT
AS
/*
    Created by: 20200831@Louisa
    Task: Get Result data from DBPRO [Redmine:#140407]
    DB: DBPRO/BODB02  
    
    Revisions:            
		- 20200831@Louisa: Get Result data from DBPRO [Redmine:#140407]

	Param's explanation:
		Web run this SP to get data from PRODUCTION
		@MatchId: MatchId on PRODUCTION
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @SportType SMALLINT

	SELECT  @SportType = m.Sporttype FROM dbo.Match m WITH(NOLOCK) WHERE m.MatchID = @MatchId
	
	DECLARE @tblResultDetail TABLE
	(
		ResourceId	VARCHAR(20)
		,HomeValue	VARCHAR(50)
		,AwayValue	VARCHAR(50)
		,ResultStatusID	TINYINT
		,SettlementStatusID	TINYINT
		,CreateDate		DATETIME
		,LastModifyDate	DATETIME
		,CreateBy		INT
		,LastModifyBy	INT
		,OtherInfo		VARCHAR(50)
	)
	DECLARE @tblExternalResult TABLE
	(
		MatchId3rd	INT
		,SourceId	SMALLINT
		,ResourceId	VARCHAR(20)
		,HomeValue	VARCHAR(50)
		,AwayValue	VARCHAR(50)
		,OtherInfo	VARCHAR(50)
		,CreateDate	DATETIME
		,LastModifyDate	DATETIME
		,CreateBy		INT
		,LastModifyBy	INT
	)

	IF @SportType =  43
	BEGIN
		INSERT INTO @tblResultDetail
		(
			ResourceId
			,HomeValue
			,AwayValue
			,ResultStatusID
			,SettlementStatusID
			,CreateDate
			,LastModifyDate
			,CreateBy
			,LastModifyBy
			,OtherInfo
		)
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
		FROM ResultDetailES r  WITH(NOLOCK)
		WHERE r.MatchID  = @MatchId

		---ExternalResult
		INSERT INTO @tblExternalResult
		(
			MatchId3rd
			,SourceId
			,ResourceId
			,HomeValue
			,AwayValue
			,OtherInfo
			,CreateDate
			,LastModifyDate
			,CreateBy
			,LastModifyBy
		)
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
		FROM	ProviderExternalResultDetailES er WITH(NOLOCK)
		WHERE er.MatchID = @MatchId
	END

	SELECT * FROM @tblResultDetail

	SELECT * FROM @tblExternalResult

END
GO