/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ArchiveDataSel]   
	@BatchNo INT = 2000
	,@TableName VARCHAR(50)
	,@JsonInfo VARBINARY(MAX) OUTPUT

AS  
/* 
	 Creator: Kathy  
	 Date: 20230308@Kathy  
	 Task: backup data of 2 table single_calculate_queue & parlay_calculate_queue [Redmine:#184726]  
	  
	   
	 Revisions:  
		- 20230308@Kathy: create SP [Redmine:#184726]   
		- 20250718@Max: Support Daily Settlement Report for Vega project [Redmine: #233410]
		
	 Param's Explanation:  
    
*/  
BEGIN  
	SET NOCOUNT ON  

	DECLARE @ArchiveDate DATE
		, @maxValue BIGINT
		, @LastRow	BIGINT

	SET @ArchiveDate = DATEADD(DAY, -1, GETDATE())

	CREATE TABLE #tmpJson (
		keyid INT
		, MatchId INT
		, eventdate DATETIME
		, IsCalculating INT
		, AdminId INT
		, IP VARCHAR(15)
		, Starttime DATETIME
		, Action VARCHAR(20)
		, sqlCommand NVARCHAR(MAX)
		, TryCount INT
		, execTime DATETIME
		, duration INT
		, creator INT
	)

	IF @TableName = 'Single_Calculate_Queue'
	BEGIN
		SET @LastRow = (SELECT VValue FROM [bodb02].[dbo].SystemSettings WITH (NOLOCK) WHERE VName = 'Single_Calculate_Queue')
		SET @maxValue = (SELECT MAX(keyid) FROM dbo.Single_Calculate_Queue s WITH(NOLOCK))

		INSERT INTO #tmpJson (
				keyid 
				, matchid 
				, eventdate 
				, IsCalculating 
				, AdminId
				, IP 
				, Starttime 
				, Action 
				, sqlCommand 
				, TryCount
				, execTime 
				, duration
				)
		SELECT	TOP (@BatchNo)
				s.keyid 
				, s.matchid 
				, m.eventdate 
				, s.IsCalculating 
				, s.AdminId
				, s.IP 
				, s.Starttime 
				, s.Action 
				, s.sqlCommand 
				, s.TryCount
				, s.execTime 
				, s.duration
		FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON s.matchid = m.matchid
		WHERE s.keyid <= @maxValue AND s.keyid > @LastRow
			AND CONVERT(DATE, Starttime) = @ArchiveDate

		SET @JsonInfo = COMPRESS((
			SELECT	TOP (@BatchNo)
					s.keyid AS 'k'
					, s.matchid AS 'm'
					, s.eventdate AS 'evd'
					, s.IsCalculating AS 'i'
					, s.AdminId AS 'aid'
					, s.IP AS 'ip'
					, s.Starttime AS 'st'
					, s.Action AS 'a'
					, s.sqlCommand AS 's'
					, s.TryCount AS 't'
					, s.execTime AS 'et'
					, s.duration AS 'd'
			FROM	#tmpJson s
			ORDER BY keyid
			FOR JSON PATH 
		))
	END
	ELSE IF @TableName = 'Parlay_Calculate_Queue'
	BEGIN
		SET @LastRow = (SELECT VValue FROM [bodb02].[dbo].SystemSettings WITH (NOLOCK) WHERE VName = 'Parlay_Calculate_Queue')
		SET @maxValue = (SELECT MAX(keyid) FROM dbo.Parlay_Calculate_Queue s WITH(NOLOCK))

		INSERT INTO #tmpJson (
				keyid 
				, matchid 
				, eventdate 
				, IsCalculating 
				, creator
				, IP 
				, Starttime 
				, Action 
				, TryCount
				, execTime 
				, duration
				)
		SELECT	TOP (@BatchNo)
				p.keyid 
				, p.matchid 
				, m.eventdate 
				, p.IsCalculating 
				, p.Creator 
				, p.IP 
				, p.Starttime 
				, p.Action
				, p.TryCount 
				, p.execTime
				, p.duration
		FROM	dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON p.matchid = m.matchid
		WHERE p.keyid <= @maxValue AND p.keyid > @LastRow
			AND CONVERT(DATE, Starttime) = @ArchiveDate

		SET @JsonInfo = COMPRESS((
			SELECT	TOP (@BatchNo)
					p.keyid AS 'k'
					, p.matchid AS 'm'
					, p.eventdate AS 'evd'
					, p.IsCalculating AS 'i'
					, p.Creator AS 'aid'
					, p.IP AS 'ip'
					, p.Starttime AS 'st'
					, p.Action AS 'a'
					, p.TryCount AS 't'
					, p.execTime AS 'et'
					, p.duration AS 'd'
			FROM	#tmpJson p
			ORDER BY keyid
			FOR JSON PATH
		))
	END

	DROP TABLE #tmpJson

END  
GO