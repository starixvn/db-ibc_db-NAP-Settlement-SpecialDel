/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchSel_s164
	@FromDate		DATETIME
	,@ToDate		DATETIME
	,@MatchCode 	NVARCHAR(50) 	= ''
	,@Status		VARCHAR(200) 	= ''
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
			,@IsRefund	BIT				= 0
	DECLARE @tblEventStatus TABLE (EventStatus VARCHAR(20))
	
	-------------------------------------------------------------------------------------------------
	SET @MatchCode = ISNULL(@MatchCode,'')
	
	IF @MatchCode <> ''
	BEGIN 
		BEGIN TRY 
			SET @MatchId = CASE WHEN ISNUMERIC(@MatchCode) = 1 THEN CAST(@MatchCode AS INT) ELSE NULL END
		END TRY  
		BEGIN CATCH
			SET @MatchId = NULL
		END CATCH
		
		SET @EventStatus = NULL
	END
	
	----------check status
	INSERT INTO @tblEventStatus(EventStatus)
	SELECT Val 
	FROM dbo.f_SplitString(@Status, ',')
	
	IF EXISTS (SELECT TOP 1 1 FROM @tblEventStatus HAVING COUNT(*) > 1) --@Status = All
	BEGIN
		SET @IsRefund = NULL
	END
	ELSE 
	BEGIN
		UPDATE @tblEventStatus
		SET EventStatus = 'completed'
			,@IsRefund = 1
		WHERE EventStatus = 'refund'
	END
	------------end check status
	
	--------------------------------------------------------------------------------------------------------
	SELECT	m.matchid
			,m.matchcode
			,m.leagueid
			,m.kickofftime
			,m.eventdate
			,m.eventstatus 
			,m.betstatus
	FROM	dbo.[match] m WITH (NOLOCK)
	WHERE	m.sporttype = @Sporttype
			AND m.eventdate BETWEEN @FromDate AND @ToDate
			AND m.eventstatus IN (SELECT DISTINCT EventStatus FROM @tblEventStatus)
			AND (@MatchCode = '' OR m.matchid = @MatchId OR m.matchcode = @MatchCode)		
			AND ( @IsRefund IS NULL 
				OR (@IsRefund = 0 AND ISNULL(m.betstatus,'') NOT LIKE 'Refund%')
				OR (@IsRefund = 1 AND ISNULL(m.betstatus,'') LIKE 'Refund%')
			)
	ORDER BY m.Matchid
	
END
GO