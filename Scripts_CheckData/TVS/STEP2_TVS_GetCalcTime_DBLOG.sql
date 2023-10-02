/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="" viewers="" isFunction="0"></info>*/
USE bodb_CustomerLog_Archive
GO

DECLARE
	@RequestInfoGetCalcTimes VARCHAR(MAX) = ''

BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpRequestInfo TABLE (
		 Sporttype			SMALLINT
		,MatchId			INT
		,CalcHalfTime		DATETIME
		,CalcFullTime		DATETIME
	)
	
	INSERT INTO @tmpRequestInfo( 
		Sporttype	
		,MatchId
	)
	SELECT s, mid
	FROM STRING_SPLIT(@RequestInfoGetCalcTimes, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_RequestInfoGetCalcTimes) t
		CROSS APPLY (
				SELECT s, mid
				FROM OPENJSON(t.Decompress_RequestInfoGetCalcTimes) 
				WITH(s SMALLINT, mid INT )
			)tbl
	WHERE f.value <> ''

	UPDATE t
	SET CalcHalfTime = s.CalcHalfTime
		,CalcFullTime = s.CalcFullTime
	FROM @tmpRequestInfo t
		OUTER APPLY (
				SELECT  MIN(CASE WHEN Action IN ( 'CAL-HT') THEN s.Starttime ELSE NULL END) AS CalcHalfTime
				       ,MIN(CASE WHEN Action NOT IN ( 'CAL-HT') THEN s.Starttime ELSE NULL END) AS CalcFullTime
				FROM dbo.Single_Calculate_Queue_bk s WITH(NOLOCK) 
				WHERE t.MatchId = s.MatchId 
				AND 1 = CASE WHEN t.Sporttype = 1 AND s.Action IN ('CAL', 'CAL-HT', 'CAL-FT') THEN 1
								WHEN t.Sporttype <> 1 AND s.Action IN ('CAL') AND sqlCommand like '%Resource Id="00"%' THEN 1
								WHEN t.Sporttype = 50 AND s.Action IN ('CAL') AND sqlCommand = '' THEN 1
								ELSE 0 END
			)s
	
	SELECT  DISTINCT MatchId		
		   ,CalcHalfTime
		   ,CalcFullTime
	FROM @tmpRequestInfo
	WHERE CalcHalfTime IS NOT NULL AND CalcFullTime IS NOT NULL 

END
GO


