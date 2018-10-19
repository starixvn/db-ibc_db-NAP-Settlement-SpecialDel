/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchSel_s164
	@FromDate		DATETIME
	,@ToDate		DATETIME
	,@MatchCode 	NVARCHAR(50) 	= ''
	,@Status		TINYINT 		= 0
	,@Sporttype		TINYINT
AS
/*
	Created by: Vicky
	Date: 20181016
	Task: Happy 5 - Settlement 
	DB: DBPRO.BODB02
	
	Revisions:
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]
		
		
	Param's Explanation:	
		@Status: All, Completed, Refund, Closed
			 	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @MatchId		INT
			,@EventStatus	NVARCHAR(50)
			,@IsRefund		BIT
	
	SET @MatchCode = ISNULL(@MatchCode,'')
	
	IF @MatchCode <> ''
	BEGIN
		SET @MatchId = CASE WHEN ISNUMERIC(@MatchCode) = 1 THEN CAST(@MatchCode AS INT) ELSE NULL END
		SET @EventStatus = NULL
	END
		
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
			,m.leagueid
			,m.kickofftime
			,m.eventdate
			,m.eventstatus 
	FROM	dbo.[match] m WITH (NOLOCK)
	WHERE	m.sporttype = @Sporttype
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