/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CalculateTime_Select]
( 
	@RequestInfoGetCalcTimes VARCHAR(MAX) = NULL
)
AS;
/*	Created by: 20230522@July
	Task: Manage Request - Add more columns to the export excel template [Redmine:#188153]
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20230522@July: Create new SP [Redmine:#188153]
		
	Param's explanation:	
			
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpRequestInfo TABLE (
		 RequestId			INT
		,Sporttype			SMALLINT
		,MatchId			INT
		,CalcHalfTime		DATETIME
		,CalcFullTime		DATETIME
	)
	
	INSERT INTO @tmpRequestInfo( 
		 RequestId			
		,Sporttype	
		,MatchId
	)
	SELECT req, s, mid
	FROM STRING_SPLIT(@RequestInfoGetCalcTimes, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_RequestInfoGetCalcTimes) t
		CROSS APPLY (
				SELECT req, s, mid
				FROM OPENJSON(t.Decompress_RequestInfoGetCalcTimes) 
				WITH( req INT, s SMALLINT, mid INT )
			)tbl
	WHERE f.value <> ''

	UPDATE t
	SET CalcHalfTime = s.CalcHalfTime
	   ,CalcFullTime = s.CalcFullTime
	FROM @tmpRequestInfo t
		OUTER APPLY (
				SELECT  MIN(CASE WHEN Action IN ( 'CAL-HT') THEN s.Starttime ELSE NULL END) AS CalcHalfTime
				       ,MIN(CASE WHEN Action NOT IN ( 'CAL-HT') THEN s.Starttime ELSE NULL END) AS CalcFullTime
				FROM dbo.Single_Calculate_Queue s WITH(NOLOCK) 
				WHERE t.MatchId = s.MatchId 
				AND 1 = CASE WHEN t.Sporttype = 1 AND s.Action IN ('CAL', 'CAL-HT', 'CAL-FT') THEN 1
							 WHEN t.Sporttype <> 1 AND s.Action IN ('CAL') AND sqlCommand like '%Resource Id="00"%' THEN 1
							 WHEN t.Sporttype = 50 AND s.Action IN ('CAL') AND sqlCommand = '' THEN 1
							 ELSE 0 END
				)s
	
	SELECT  RequestId		
		   ,CalcHalfTime
		   ,CalcFullTime
	FROM @tmpRequestInfo

END
GO


