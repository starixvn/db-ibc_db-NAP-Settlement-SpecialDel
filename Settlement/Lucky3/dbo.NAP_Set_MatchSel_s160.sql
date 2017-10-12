/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchSel_s160
	@FromDate	DATETIME
	,@ToDate	DATETIME
	,@MatchCode NVARCHAR(50) = ''
	,@Status	TINYINT = 0
AS
/*
	Created by: Kathy
	Date: 20170426
	Task: Lucky 3 - Settlement 
	DB: DBPRO.BODB02
	
	Revisions:
		20170426@Kathy: Lucky 3 - Settlement  [Redmine:#77170]
		
		
	Param's Explanation:	
		@Status: 0 - All
				1 - Running
				2 - Closed
				3 - Completed
				4 - Refund
				
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @MatchId		INT
			,@EventStatus	NVARCHAR(50)
			,@IsRefund		BIT
	
	SET @MatchCode = ISNULL(@MatchCode,'')
	
	IF @MatchCode <> ''
		SET @MatchId = CASE WHEN ISNUMERIC(@MatchCode) = 1 THEN CAST(@MatchCode AS INT) ELSE NULL END						
		
	SELECT @EventStatus = CASE
							WHEN @Status = 1 THEN 'running'
							WHEN @Status = 2 THEN 'closed'
							WHEN @Status IN (3,4) THEN 'completed'
							ELSE NULL
							END
			,@IsRefund = CASE 
							WHEN @Status = 4 THEN 1 
							WHEN @Status <> 0 THEN 0
							ELSE NULL END
		
	SELECT	m.matchid
			,m.matchcode
			,m.kickofftime
			,m.eventdate
			,b.FirstBall
			,b.SecondBall
			,b.ThirdBall
			,m.livehomescore -- number of 1st prize
			,m.liveawayscore -- number of 2nd prize
			,m.finalhomescore -- number of 3rd prize
			,CASE 
				WHEN m.betstatus LIKE 'Refund%' THEN 'Refund'   
				ELSE m.eventstatus 
			END AS eventstatus
	FROM	dbo.match m WITH(NOLOCK)
		LEFT JOIN (
			SELECT Matchid, FirstBall, SecondBall, ThirdBall
			FROM (
				SELECT	b.Matchid
						,CASE WHEN b.Seq = 1 THEN 'FirstBall'
							WHEN b.Seq = 2 THEN 'SecondBall'
							when b.Seq = 3 THEN 'ThirdBall'
						END AS seq 
						,Number
				FROM	dbo.bingoBall b WITH(NOLOCK)
			)AS s
			PIVOT (
				MAX(s.Number)
				FOR seq IN (FirstBall, SecondBall, ThirdBall)
			) AS pvt
		) b
			ON m.matchid = b.Matchid
	WHERE	m.sporttype = 160
			AND m.eventdate BETWEEN @FromDate AND @ToDate
			AND (@EventStatus IS NULL OR m.eventstatus = @EventStatus )
			AND (@MatchCode = '' OR m.matchid = @MatchId OR m.matchcode = @MatchCode)		
			AND ( @IsRefund IS NULL 
				OR (@IsRefund = 0 AND ISNULL(m.betstatus,'') NOT LIKE 'Refund%')
				OR (@IsRefund = 1 AND ISNULL(m.betstatus,'') LIKE 'Refund%')
			)
	ORDER BY m.Matchid
END
GO