/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SideDB_Service_CalculationLogSel]
	
AS
/*
	Created by: 20201123@Kathy
	Task: Settlement  
	
	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @LastLogId BIGINT
			,@LastStatusId TINYINT
			,@IsSkip BIT
			,@LogId BIGINT
			,@TransInfo XML
			,@TableName VARCHAR(128)

	SELECT TOP (1) @LastLogId = LastLogId 
			,@LastStatusId = LastStatusId
			,@IsSkip = IsSkip
	FROM	dbo.Service_SiteDB_LastLog WITH(NOLOCK)
	
	IF @LastStatusId = 2 OR @IsSkip = 1
	BEGIN
		SELECT	TOP 1 @LogId = LogId
				,@TransInfo = TransInfo
				,@TableName = TableName
		FROM	dbo.Service_SiteDB_CalculationLog WITH(NOLOCK)
		WHERE	LogId > @LastLogId
		ORDER BY LogId
	END

	SELECT	@LogId AS LogId
			,@TransInfo AS TransInfo
			,@TableName AS TableName
END