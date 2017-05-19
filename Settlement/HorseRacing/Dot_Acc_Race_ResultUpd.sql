
ALTER PROCEDURE [dbo].[Dot_Acc_Race_ResultUpd]
	@programID varchar(10),
	@eventdate smalldatetime,
	@raceNumber int,
	@runnerNumber int,
	@placing tinyint = 0,
	@winOdds money = 0,
	@placeOdds	money = 0,
	@isSCR bit = 0,
	@isFav bit = 0,
	@userid int = 151 ----doing update status userid
AS
/*
	Task: Settlement 
	DB: DBPRO.BODB02

	Revisions:
		- 20151207@Patrick: Database - Change datatype [Redmine: #48660]
		
*/

BEGIN
	SET NOCOUNT ON;	
	
	UPDATE dbo.outright with (rowlock,updlock)
	SET 
		odds = @winOdds,
		PlaceOdds = @placeOdds,
		Placing = @placing,
		IsFavor = @isFav,
		IsSCR = @isSCR
	WHERE ProgramID = @programID 
		AND eventdate = @eventdate
		AND groupmatch = CAST(@raceNumber as varchar(20))
		AND matchcode = CAST(@runnerNumber as varchar(10))
		AND oddsstatus <> 'completed'
	
	Declare @LogData as nvarchar(300)
	SET @LogData = 'Update Result for Horse ID:' + @ProgramID + ' race:' + CAST(@raceNumber as nvarchar(20)) + ' runner:' + CAST(@runnerNumber as nvarchar(20))
		+ ' winodds:' + CONVERT(varchar(20), @winOdds, 2) + ' PlaceOdds:' + CONVERT(varchar(20), @placeOdds, 2)
		+ ' IsFavor:' + CAST(@isFav as nvarchar(1)) + ' IsSCR:' + CAST(@isSCR as nvarchar(1))
	EXEC dbo.logfile @userid, @LogData
END

GO 
 GRANT EXECUTE ON [dbo].[Dot_Acc_Race_ResultUpd] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Dot_Acc_Race_ResultUpd] TO [vnteam]
GO 
