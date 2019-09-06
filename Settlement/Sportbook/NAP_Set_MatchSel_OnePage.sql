/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSel_OnePage] 
	@FromDate DATETIME
	,@ToDate DATETIME
	,@SportTypeList VARCHAR(MAX) = '0' -- default for [None] filter
	,@Remark TINYINT = 23 -- default for [All] filter
AS
/*  
	Created by: Sol
	Date: 20190903
	Task: Match results for other sports on one page
	DB: DBTXN/BODB02
	Original: NAP_Set_MatchSel_OnePage
	Revisions:  
		- 20190903@Sol: Multi Sports on One Page - Initial sp - [Redmind: #118379]
      
	Param explanation:  
	@SportTypeList: List of sport type

*/
BEGIN
	SET NOCOUNT ON

	DECLARE 
			@StartTime DATETIME
			,@EndTime	DATETIME
			,@SqlCommand VARCHAR(MAX)
			,@isSettingByProfile BIT = 0
	
	Declare @SportTypeTable table (SportTypeId tinyint)

	SET @StartTime = GETDATE()

	-- initial data for @SportTypeTable
	INSERT INTO @SportTypeTable(SportTypeId)
	SELECT Val 
	FROM dbo.f_SplitString(@SportTypeList, ',')
	OPTION (maxrecursion 0)

	IF EXISTS (
				SELECT TOP 1 1 
				FROM @SportTypeTable t 
						CROSS APPLY 
						(
							SELECT spf.Sporttype
							FROM dbo.f_Set_SettingByProfile(SportTypeId) spf 
							WHERE t.SportTypeId = spf.SportType
						) s
				) 
	BEGIN
		SELECT @isSettingByProfile = 1
	END

	CREATE TABLE #matchList (
		HalfTimeHomeScore INT
		,HalfTimeAwayScore INT
		,matchid INT
		,leagueid INT
		,homeid INT
		,awayid INT
		,matchcode NVARCHAR(50)
		,kickofftime DATETIME
		,finalhomescore INT
		,finalawayscore INT
		,eventstatus NVARCHAR(50)
		,sporttype SMALLINT
		,eventdate DATETIME
		,suspenderHalfTime NVARCHAR(50)
		,suspenderFullTime NVARCHAR(50)
		,SettlementStatus TINYINT
		,betstatus NVARCHAR(50)
		,IsNeutral BIT
		)

	DECLARE @strmatchid VARCHAR(MAX)
		,@betstatus VARCHAR(8000)
		,@intDocHandle INT
		,@rowcount INT
		,@max_matchid INT
	DECLARE @tmp_match TABLE (matchid INT)

	INSERT INTO #matchList (
		HalfTimeHomeScore,HalfTimeAwayScore, matchid ,leagueid ,homeid ,awayid ,matchcode ,
		kickofftime ,finalhomescore ,finalawayscore ,eventstatus,sporttype ,eventdate ,
		suspenderHalfTime, suspenderFullTime,SettlementStatus, betstatus, IsNeutral
	)
	SELECT 
		tmp.hthomescore
		,tmp.htawayscore
		,tmp.matchid
		,tmp.leagueid
		,tmp.homeid
		,tmp.awayid
		,tmp.matchcode
		,tmp.kickofftime
		,tmp.finalhomescore
		,tmp.finalawayscore
		,tmp.eventstatus
		,tmp.sporttype
		,tmp.eventdate
		,CASE mr.ConfirmHT
		WHEN 0 THEN ''
		ELSE (
				SELECT username
				FROM CustDB.dbo.custinfo WITH (NOLOCK)
				WHERE custid = mr.ConfirmHT
				)
		END suspenderHT
		,CASE mr.ConfirmFT
			WHEN 0 THEN ''
			ELSE (
					SELECT username
					FROM CustDB.dbo.custinfo WITH (NOLOCK)
					WHERE custid = mr.ConfirmFT
					)
		END suspenderFT
		,tmp.SettlementStatus
		,tmp.betstatus
		,tmp.IsNeutral
	FROM (
		SELECT hthomescore
			,htawayscore			
			,m.matchid
			,m.leagueid
			,m.homeid
			,m.awayid
			,m.matchcode
			,m.kickofftime
			,m.finalhomescore
			,m.finalawayscore
			,m.eventstatus
			,m.sporttype
			,m.eventdate
			,ISNULL(m.SettlementStatus, 0) AS SettlementStatus
			,m.betstatus
			,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
		FROM	dbo.match m WITH (NOLOCK)
				INNER JOIN @SportTypeTable t 
					on m.sporttype = t.SportTypeId
		WHERE m.eventdate BETWEEN @FromDate AND @ToDate 
			AND (@Remark & m.SettlementStatus > 0)
			AND m.sporttype <> 1 AND m.sporttype < 100 -- sportbook - other sports - from 1 to 99 excluded soccer
	) tmp
	LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON tmp.matchid = mr.matchid

	SELECT	m.HalfTimeHomeScore
			,m.HalfTimeAwayScore
			,m.matchid
			,m.leagueid
			,m.homeid
			,m.awayid
			,m.matchcode
			,m.kickofftime
			,m.finalhomescore
			,m.finalawayscore
			,m.eventstatus
			,m.sporttype
			,m.eventdate
			,m.suspenderHalfTime
			,m.suspenderFullTime
			,m.SettlementStatus
			,m.betstatus
			,m.IsNeutral
	FROM	#matchList m
	ORDER BY case m.eventstatus when 'completed' then 1 when 'refund' then 1 else 0 END
		,m.eventdate
		,m.kickofftime
		,m.sporttype
		,m.leagueid
		,m.matchid
		,m.betstatus
		,m.matchcode			

	DROP TABLE #matchList
	
	SET @EndTime = GETDATE()
	
	IF DATEDIFF(MILLISECOND,@StartTime, @EndTime) > 10000
	BEGIN
		SET @SqlCommand = 'EXEC NAP_Set_MatchSel_OnePage @FromDate =''' + CONVERT(VARCHAR(20), @FromDate) + ''''
						+ ', @ToDate = ''' + CONVERT(VARCHAR(20), @ToDate) + ''''
						+ ', @SportTypeList = ''' + @SportTypeList + ''''
						+ ', @Remark =' + CONVERT(VARCHAR(10), @Remark)  
						
		INSERT INTO SettlementRunSPLog(LogDate, SqlCommand, StartTime, EndTime)
		SELECT GETDATE(), @SqlCommand, @StartTime, @EndTime
	END
END
GO
