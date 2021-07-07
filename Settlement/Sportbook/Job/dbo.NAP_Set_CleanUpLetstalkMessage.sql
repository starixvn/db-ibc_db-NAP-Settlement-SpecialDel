/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_Set_CleanUpLetstalkMessage
AS
/*
	Created by: Louisa
	Date: 20210706
	Task: Letstalk message [Redmine:#157540]
	DB: DBTXN/bodb02

	Revisions:
		20210706@Louisa: Cleanup Letstalk message older 14 days [Redmine:#157540]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @batch INT = 1000
	DECLARE @compareDate DATETIME

	SET @compareDate =  CONVERT(VARCHAR(10),DATEADD (DAY, -14, GETDATE()), 102)
	
	WHILE (1=1)
	BEGIN
		DELETE TOP(@batch) FROM dbo.Settlement_LetstalkMessage WITH(ROWLOCK, UPDLOCK)
		WHERE CreateDate < @compareDate
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

END