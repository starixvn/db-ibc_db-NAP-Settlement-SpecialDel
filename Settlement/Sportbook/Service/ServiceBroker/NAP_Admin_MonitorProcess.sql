ALTER PROCEDURE dbo.NAP_Admin_MonitorProcess
	@SessionId BIGINT
	,@MatchId INT
AS
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT	@matchid AS matchid
			,1 AS KeyId

	WHILE (1=1)
	BEGIN
		IF EXISTS (SELECT top 1 1 FROM dbo.SettlementProcessing WITH (NOLOCK) WHERE SessionId = @SessionId)
			WAITFOR DELAY '00:00:01'
		ELSE 
		BEGIN
			BREAK
		END
	END
	
	EXEC dbo.NAP_Admin_Calculate_Main @mode = 'ReleaseMatch'
		,@IsSettingByProfile = 1
		,@SessionId = @SessionId

	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1

	DROP TABLE #tblMatchProcess

	insert into SettlementTestLog (matchid, stepname, session, logtime, doing) 
	values (@matchid, 'cal - end', @SessionId, getdate(), 'threads: ' + cast (6 as varchar))
	
END