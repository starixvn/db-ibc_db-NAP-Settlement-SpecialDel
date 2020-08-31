/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_Set_CloneResultDetailIns
	@MatchId INT
	,@SportType SMALLINT
	,@ResultDetail VARCHAR(MAX) = ''
	,@ExternalResult VARCHAR(MAX) = ''
	,@ErrCode INT  = 0OUTPUT	 
	,@ErrMsg NVARCHAR(200) = '' OUTPUT	
AS
/*
    Created by: 20200831@Louisa
    Task: Copy Result from DBPRO to SIT [Redmine:#140407]
    DB: DBPRO/BODB02  
    
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
				<Result ResourceID= "M1" HomeValue="4" AwayValue="2" ResultStatusID="5" SettlementStatusID="4" CreateBy="8" CreateDate="2020-08-19 06:12:00.000" LastModifyBy="8" LastModifyDate="2020-08-19 06:12:00.000" OtherInfo="test"/>
			</Results>'
		
*/
BEGIN

SET NOCOUNT ON

	DECLARE @xmlResultDetail XML, @xmlExternalResult XML

	DECLARE @tblResultDetail TABLE
	(
		 ResourceId	varchar(20)
		,HomeValue	varchar(50)
		,AwayValue	varchar(50)
		,ResultStatusID	tinyint
		,SettlementStatusID	tinyint
		,CreateDate	datetime
		,LastModifyDate	datetime
		,CreateBy	int
		,LastModifyBy	int
		,OtherInfo	varchar(50)
	)
	DECLARE @tblExternalResult TABLE
	(
		MatchId3rd	int
		,SourceId	smallint
		,ResourceId	varchar(20)
		,HomeValue	varchar(50)
		,AwayValue	varchar(50)
		,OtherInfo	varchar(50)
		,CreateDate	datetime
		,LastModifyDate	datetime
		,CreateBy	int
		,LastModifyBy	int
	)

BEGIN TRY

	IF @ResultDetail <> ''
	BEGIN
		SELECT @xmlResultDetail = CAST(@ResultDetail AS XML)
		IF @SportType = 43
		BEGIN
			INSERT INTO dbo.ResultDetailES
			(
				MatchId
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
				1234567
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
				,1234567
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

					