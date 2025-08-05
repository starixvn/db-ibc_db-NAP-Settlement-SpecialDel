/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[CustWinLimitBet_History_Del_InHouse_Delete]
	@Day INT = 7
AS
/*
	Created: 20250805@Louisa	
	Task: Cleanup data
	DB: 
	
	Revisions:
		- 20250805@Louisa: Created [RedmineID: #235249]

	Example:			
*/ 
BEGIN
	DECLARE @Archive_Date DATETIME2

	SELECT @Archive_Date = DATEADD(DAY, -@Day, GETDATE())

	IF OBJECT_ID('CustWinLimitBet_History_Del_InHouse', 'U') IS NOT NULL
	BEGIN
		WHILE (1=1)
		BEGIN
			DELETE TOP(5000) c
			FROM dbo.CustWinLimitBet_History_Del_InHouse c WITH (ROWLOCK)
			WHERE c.RepUpdateTime < @Archive_Date

			IF @@ROWCOUNT = 0 BREAK

			WAITFOR DELAY '00:00:00.180'
		END

	END
END
GO



