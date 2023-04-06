USE [bodb02]
/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_DeleteBettrans_Staging_s213_Job]
AS
	/*
		Create: Johnson
		Date: 20160908
		Task: delete old transaction in bettrans_stagging
		DB: DBTXN/bodb02
		
		Revision:
		
		Parameter's Explanation:
		
	*/
BEGIN
	SET NOCOUNT ON
	
	DELETE bg
	FROM bettrans_staging bg WITH(UPDLOCK,ROWLOCK)
		INNER JOIN bettrans14 b WITH(NOLOCK) ON bg.OBTransId = b.transid
	
	DECLARE @eventdate DATE
	
	SELECT @eventdate = DATEADD(month,-1,getdate())
	
	BEGIN TRY
		INSERT INTO DBARC.bodb_Archive.dbo.SettlementNG2_Message_bk (
			[SeqID]
			,[CreationTime]
           ,[DoneAPI_Time]
           ,[TotalRow]
           ,[StartCalculate_Time]
           ,[DoneCalculate_Time]
           ,[Status]
           ,[Task]
           ,[EventDate]
           ,[GambleID]
           ,[MatchId])
		SELECT  [SeqID]
			,[CreationTime]
           ,[DoneAPI_Time]
           ,[TotalRow]
           ,[StartCalculate_Time]
           ,[DoneCalculate_Time]
           ,[Status]
           ,[Task]
           ,[EventDate]
           ,[GambleID]
           ,[MatchId]
		FROM SettlementNG2_Message WITH(NOLOCK)
		WHERE eventdate < @eventdate	

		DELETE SettlementNG2_Message WITH(UPDLOCK)
		WHERE eventdate < @eventdate
	END TRY
	BEGIN CATCH
		
	END CATCH
	
END
GO


