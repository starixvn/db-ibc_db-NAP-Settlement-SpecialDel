/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE NAP_Set_CleanUp_SettlementResultDetailHistory_Job
AS
/* 
	Created:20220324@Louisa
    Task: Trigger on ResultDetail/OS/ES [Redmine:#170548]
    DB: DBTP/bodb02
	
	Revisions:
		- 20220324@Louisa: Cleanup History data for trigger on table ResultDetail/OS/ES [Redmine:#170548]
		- 20220928@Kathy: Cleanup History data for trigger on table match
		- 20250325@Hughie: Cleanup History data for trigger on table match3rd, VSOutright, VSRaceInfo, SMP_MarketSelection_History, SMP_Market_History [Redmine:#221187]
*/
BEGIN
    SET NOCOUNT ON

	DECLARE @batch INT = 1000
	DECLARE @compareDate DATETIME

	SET @compareDate = CONVERT(VARCHAR(10),DATEADD (DAY, -7, GETDATE()), 120)

	WHILE (1=1)
	BEGIN

		DELETE TOP(@batch) r
		FROM dbo.SettlementResultDetailHistory r WITH(ROWLOCK, UPDLOCK)
		WHERE MatchId > 0 AND r.UpdateTime < @compareDate
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

	WHILE (1=1)
	BEGIN

		DELETE TOP(@batch) mt
		FROM dbo.Match_Tracking mt WITH(ROWLOCK, UPDLOCK)
		WHERE mt.UpdateTime < @compareDate
	
		IF @@ROWCOUNT < @batch
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

	WHILE (1=1)
	BEGIN

		DELETE TOP(@batch) ms
		FROM dbo.SMP_MarketSelection_History ms WITH(ROWLOCK, UPDLOCK)
		WHERE ms.LogDate < @compareDate
	
		IF @@ROWCOUNT < @batch
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

	WHILE (1=1)
	BEGIN

		DELETE TOP(@batch) mh
		FROM dbo.SMP_Market_History mh WITH(ROWLOCK, UPDLOCK)
		WHERE mh.LogDate < @compareDate
	
		IF @@ROWCOUNT < @batch
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

	WHILE (1=1)
	BEGIN

		DELETE TOP(@batch) m3t
		FROM dbo.Match3rd_Tracking m3t WITH(ROWLOCK, UPDLOCK)
		WHERE m3t.UpdateTimeHistory < @compareDate
	
		IF @@ROWCOUNT < @batch
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

	WHILE (1=1)
	BEGIN

		DELETE TOP(@batch) vot
		FROM dbo.VSOutright_Tracking vot WITH(ROWLOCK, UPDLOCK)
		WHERE vot.UpdateTime < @compareDate
	
		IF @@ROWCOUNT < @batch
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

	WHILE (1=1)
	BEGIN

		DELETE TOP(@batch) vrt
		FROM dbo.VSRaceInfo_Tracking vrt WITH(ROWLOCK, UPDLOCK)
		WHERE vrt.UpdateTime < @compareDate
	
		IF @@ROWCOUNT < @batch
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

END
GO
