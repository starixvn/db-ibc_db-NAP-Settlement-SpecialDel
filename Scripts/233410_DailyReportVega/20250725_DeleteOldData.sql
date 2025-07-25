/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/* 
	 Creator: Max  
	 Date: 20250725  
	 Task: DSupport Daily Settlement Report for Vega project [Redmine: #233410]
	 DB: DBTXN/BODB02  
	 Original: Admin_Settlement_1  
	   
	 Revisions:  
		- 20250725@Max: Support Daily Settlement Report for Vega project [Redmine: #233410]

	 Param's Explanation:  
    
*/ 

USE bodb02

BEGIN  
	--Remove old data Single_Calculate_Queue & Parlay_Calculate_Queue
	DECLARE @LastRow	BIGINT
		,@ArchiveDate DATETIME

	SET @ArchiveDate = DATEADD(DAY, -2, GETDATE())
	
	--Single_Calculate_Queue
	SET @LastRow = ISNULL((SELECT VValue FROM [bodb02].[dbo].SystemSettings WITH (NOLOCK) WHERE VName = 'Single_Calculate_Queue'),0)
	WHILE(1=1) 
	BEGIN
		DELETE TOP (1000)
		FROM dbo.Single_Calculate_Queue WITH(ROWLOCK, UPDLOCK)
		WHERE Starttime < @ArchiveDate
			AND keyid < @LastRow

		IF @@ROWCOUNT < 1000
			BREAK
	END

	--Parlay_Calculate_Queue
	SET @LastRow = ISNULL((SELECT VValue FROM [bodb02].[dbo].SystemSettings WITH (NOLOCK) WHERE VName = 'Parlay_Calculate_Queue'),0)
	WHILE(1=1) 
	BEGIN
		DELETE TOP (1000)
		FROM dbo.Parlay_Calculate_Queue WITH(ROWLOCK, UPDLOCK)
		WHERE Starttime < @ArchiveDate
			AND keyid < @LastRow

		IF @@ROWCOUNT < 1000
			BREAK
	END
END  
GO