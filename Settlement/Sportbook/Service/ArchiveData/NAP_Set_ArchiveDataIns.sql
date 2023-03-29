/*<info serverAlias="DBLOG-bodb_CustomerLog_archive,DBLOG_STANDBY-bodb_CustomerLog_archive" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ArchiveDataIns]
	@SiteDBGroupId SMALLINT
	,@TableName VARCHAR(50)
	,@JsonInfo VARBINARY(MAX)

AS  
/* 
	 Creator: Kathy  
	 Date: 20230308@Kathy  
	 Task: backup data of 2 table single_calculate_queue & parlay_calculate_queue [Redmine:#184726]    
	   
	 Revisions:  
		- 20230308@Kathy: create SP [Redmine:#184726]  
		
	 Param's Explanation:  
    
*/  
BEGIN  
	SET NOCOUNT ON  

	DECLARE @Decompress_JsonInfo NVARCHAR(MAX)

	SET @Decompress_JsonInfo = CAST(DECOMPRESS(@JsonInfo) AS NVARCHAR(MAX))

	IF @TableName = 'Single_Calculate_Queue'
	BEGIN
		INSERT INTO dbo.single_Calculate_queue_bk(matchid, eventdate, iscalculating, adminid, ip, starttime, action, sqlcommand, trycount, exectime, duration, sitedbGroupId)
		SELECT m AS MatchId
			,evd AS EventDate
			,i AS IsCalculating
			,aid AS AdminId
			,ip
			,st AS StartTime
			,a AS Action
			,s AS SqlCommand
			,t AS TryCount
			,et AS ExecTime
			,d AS Duration
			,@SiteDBGroupId AS sitedbGroupId
		FROM	OPENJSON(@Decompress_JsonInfo)
			WITH(m INT
				,evd DATETIME
				,i INT
				,aid INT
				,ip VARCHAR(15)
				,st DATETIME
				,a VARCHAR(20)
				,s NVARCHAR(MAX)
				,t INT
				,et DATETIME
				,d INT
			)
		
	END
	ELSE IF @TableName = 'Parlay_Calculate_Queue'
	BEGIN
		INSERT INTO dbo.Parlay_Calculate_queue_bk(matchid, eventdate, iscalculating, Creator, ip, starttime, action, trycount, exectime, duration, sitedbGroupId)
		SELECT m AS MatchId
			,evd AS EventDate
			,i AS IsCalculating
			,aid AS creator
			,ip
			,st AS StartTime
			,a AS Action		
			,t AS TryCount
			,et AS ExecTime
			,d AS Duration			
			,@SiteDBGroupId AS sitedbGroupId
		FROM	OPENJSON(@Decompress_JsonInfo)
			WITH(m INT
				,evd DATETIME
				,i INT
				,aid INT
				,ip VARCHAR(15)
				,st DATETIME
				,a VARCHAR(20)				
				,t INT
				,et DATETIME
				,d INT
			)
	END

END  
GO

