/*<info serverAlias="DBBAH-bodb02,DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/  
ALTER PROCEDURE [dbo].[Task_CustWinLimitBet_CleanUp] 
	@Date INT = 30
AS
/*	
	Created: 20250416@Louisa
	Task:  Potential Winning Limit/Threshold [Redmine:#226060]
	DB: DBBAH-bodb02,DBSIC/bodb02
	
	Revisions:
		- 20250416@Louisa:  Potential Winning Limit/Threshold [Redmine:#226060]
*/
BEGIN
    SET NOCOUNT ON
	
	DECLARE @FromDate DATE
			,@batchNo INT
	
	SET @batchNo = 5000
	SET @FromDate = DATEADD(DAY, -@Date,GETDATE() )


	IF @@SERVERNAME LIKE '%DBSITEC3%' OR @@SERVERNAME = 'TESTSITEDB2'
	BEGIN
		WHILE(1=1)
		BEGIN
			DELETE	TOP (@batchNo)
			FROM	dbo.CustWinLimitBet_History WITH(ROWLOCK, UPDLOCK)		
			OUTPUT deleted.ID, [dbo].[f_GetDateTime2]()
			INTO CustWinLimitBet_History_Del_InHouse (ID,RepUpdateTime)
			WHERE	RepUpdateTime  < @FromDate

			IF @@ROWCOUNT < @batchNo
				BREAK
		END
		
		WHILE(1=1)
		BEGIN
			DELETE	TOP (@batchNo)
			FROM	dbo.CustWinLimitBet_Errors WITH(ROWLOCK, UPDLOCK)
			WHERE	CreatedDate  < @FromDate

			IF @@ROWCOUNT < @batchNo
				BREAK
		END

	END
	ELSE
	BEGIN
		WHILE(1=1)
		BEGIN
			DELETE	TOP (@batchNo)
			FROM	dbo.CustWinLimitBet_History WITH(ROWLOCK, UPDLOCK)
			WHERE	RepUpdateTime  < @FromDate

			IF @@ROWCOUNT < @batchNo
				BREAK
		END
	END


END