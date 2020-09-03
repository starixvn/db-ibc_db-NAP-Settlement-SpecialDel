/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_CloneResultDetailToSIT
	 @MatchId		 INT
	,@ResultDetail	 VARCHAR(MAX) = ''
	,@ExternalResult VARCHAR(MAX) = ''
	,@ErrCode		 INT  = 0 OUTPUT	 
	,@ErrMsg		 NVARCHAR(200) = '' OUTPUT	
AS
/*
    Created by: 20200831@Louisa
    Task: Copy Result from DBPRO to SIT [Redmine:#140407]
    DB: DBPRO/BODB02  
	NOTE: This SP get data for QC Test, only deployed on SIT
    
    Revisions:            
		- 20200831@Louisa: Copy Result from DBPRO to SIT [Redmine:#140407]

	Param's explanation:
		@MatchId: MatchId on SIT (this match follow results from a PRODUCTION match)
		@ExternalResult = 
		'<Results>
			<Result MatchId3rd="6166" SourceId="201" ResourceId="M1" HomeValue="1" AwayValue="1" OtherInfo="test" CreateDate="2020-08-17 03:24:12.970" CreateBy="148" LastModifyDate="2020-08-17 03:24:12.970" LastModifyBy="148"/>
			<Result MatchId3rd="0" SourceId="100" ResourceId="M1" HomeValue="1" AwayValue="1" OtherInfo="test" CreateDate="2020-08-17 03:24:12.970" CreateBy="148" LastModifyDate="2020-08-17 03:24:12.970" LastModifyBy="148"/>
			<Result MatchId3rd="6166" SourceId="16" ResourceId="M1" HomeValue="1" AwayValue="1" OtherInfo="test" CreateDate="2020-08-17 03:24:12.970" CreateBy="148" LastModifyDate="2020-08-17 03:24:12.970" LastModifyBy="148"/>
			<Result MatchId3rd="0" SourceId="1001" ResourceId="M1" HomeValue="1" AwayValue="1" OtherInfo="test" CreateDate="2020-08-17 03:24:12.970" CreateBy="148" LastModifyDate="2020-08-17 03:24:12.970" LastModifyBy="148"/>
			<Result MatchId3rd="0" SourceId="1002" ResourceId="M1" HomeValue="1" AwayValue="1" OtherInfo="test" CreateDate="2020-08-17 03:24:12.970" CreateBy="148" LastModifyDate="2020-08-17 03:24:12.970" LastModifyBy="148"/>
		</Results>'

		@ResultDetail = 
		'<Results>
			<Result ResourceId= "M1" HomeValue="4" AwayValue="2" ResultStatusID="5" SettlementStatusID="4" CreateBy="8" CreateDate="2020-08-19 06:12:00.000" LastModifyBy="8" LastModifyDate="2020-08-19 06:12:00.000" OtherInfo="test"/>
		</Results>'
		
*/
BEGIN

SET NOCOUNT ON

	DECLARE @xmlResultDetail XML, @xmlExternalResult XML
	DECLARE @SportType SMALLINT

	SELECT  @SportType = m.Sporttype FROM dbo.Match m WITH(NOLOCK) WHERE m.MatchID = @MatchId

BEGIN TRY

	IF @ResultDetail <> ''
	BEGIN
		SELECT @xmlResultDetail = CAST(@ResultDetail AS XML)
		
		IF @SportType = 43
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetailES r WITH(NOLOCK) WHERE r.MatchID = @MatchId)
			BEGIN
				DELETE FROM dbo.ResultDetailES WHERE MatchID =  @MatchId
			END
			
			INSERT INTO dbo.ResultDetailES
			(
				MatchID
				,ResourceId
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
				@MatchId
				,T.C.value('@ResourceId','varchar(20)'	)
				,T.C.value('@HomeValue'	,'varchar(50)'	)
				,T.C.value('@AwayValue'	,'varchar(50)'	)
				,T.C.value('@ResultStatusID',	'tinyint'	)
				,T.C.value('@SettlementStatusID' , 'tinyint' )
				,T.C.value('@CreateDate' , 'datetime' )
				,T.C.value('@LastModifyDate' ,'datetime' )
				,T.C.value('@CreateBy' , 'int' )
				,T.C.value('@LastModifyBy' ,'int' )
				,T.C.value('@OtherInfo' , 'varchar(50)' )
			FROM	@xmlResultDetail.nodes('/Results/Result') AS T(C)
		END
	END

	IF @ExternalResult <> ''
	BEGIN
		SELECT @xmlExternalResult =  CAST(@ExternalResult AS XML)
		
		IF @SportType = 43
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM dbo.ProviderExternalResultDetailES er WITH(NOLOCK) WHERE er.MatchID = @MatchId)
			BEGIN
				DELETE FROM dbo.ProviderExternalResultDetailES WHERE MatchID =  @MatchId
			END

			INSERT INTO dbo.ProviderExternalResultDetailES
			(
				MatchId3rd
				,MatchId
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
				T.C.value('@MatchId3rd' , 'int' )
				,@MatchId
				,T.C.value('@SourceId'	 , 'smallint' )
				,T.C.value('@ResourceId' , 'varchar(20)' )
				,T.C.value('@HomeValue'	 , 'varchar(50)' )
				,T.C.value('@AwayValue'	 , 'varchar(50)' )
				,T.C.value('@OtherInfo'	 , 'varchar(50)' )
				,T.C.value('@CreateDate' , 'datetime' )
				,T.C.value('@LastModifyDate' , 'datetime' )
				,T.C.value('@CreateBy'	 , 'int' )
				,T.C.value('@LastModifyBy' , 'int' )
			FROM	@xmlExternalResult.nodes('/Results/Result') AS T(C)
		END
	END
END TRY

BEGIN CATCH
	SELECT @ErrCode = @@ERROR
	SELECT @ErrMsg = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
END CATCH
END
GO

					