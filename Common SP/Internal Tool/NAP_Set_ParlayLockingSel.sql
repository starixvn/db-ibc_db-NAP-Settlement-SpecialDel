/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ParlayLockingSel
	@MatchId	INT = 0
	,@TimeRange INT = 1
AS
/*
	Created:20210830@Louisa
    Task: Get all matches're being locking by refno [Redmineid:#160738]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210830@Louisa: Get all matches're being locking by refno [Redmineid:#160738]
		- 20220913@Louisa: Get more info [RedmineId:#177711]

	Param's Explanation:
		@TimeRange: the range to scan data (hours)



*/
BEGIN
	SET NOCOUNT ON

	DECLARE @FromDateTime DATETIME
			, @ToDatetime DATETIME
			, @ServerName VARCHAR(100)

	SET @FromDateTime = DATEADD (HOUR, - @TimeRange, GETDATE() )
	SET @ToDatetime = DATEADD(MINUTE, -5, GETDATE())
	SET @ServerName = @@SERVERNAME

	DECLARE @tmpParlayLocking TABLE 
	(MatchId INT, Refno BIGINT, Session NVARCHAR(100), SPName SYSNAME, CreatedDate DATETIME)

	IF EXISTS (SELECT TOP 1 1 FROM dbo.ParlayLocking p WITH(NOLOCK) )
	BEGIN
		INSERT INTO @tmpParlayLocking (MatchId, Refno, Session, SPName, CreatedDate)
		SELECT i.MatchId, i.Refno, i.Session, i.SPName, i.CreatedDate
		FROM dbo.ParlayLockingHistory i WITH(NOLOCK)
		WHERE i.Action = 'I'
			AND i.CreatedDate BETWEEN @FromDateTime AND @ToDatetime
			AND ( @MatchId = 0 OR  i.MatchId =  @MatchId)
			AND NOT EXISTS (
				SELECT TOP 1 1
				FROM dbo.ParlayLockingHistory d WITH(NOLOCK)
				WHERE d.MatchId =  i.MatchId
					AND d.Refno =  i.Refno
					AND d.Session = i.Session
					AND d.Action = 'D'
					AND d.CreatedDate > i.CreatedDate
			)
	END
	
	SELECT @ServerName AS ServerName 
		,p.MatchID
		, COUNT(p.Refno) AS TotalAffectedRefno
		, p.Session 
		, p.SPName 
		, MIN(p.CreatedDate) AS CreatedDate
	FROM @tmpParlayLocking p
	GROUP BY p.MatchId, p.Session, p.SPName
	ORDER BY CreatedDate DESC

END
GO
